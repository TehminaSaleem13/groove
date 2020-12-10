class AddLogCsv
  def add_log_csv(tenant,time_of_import,file_name)
    Apartment::Tenant.switch!(tenant)
    @time_of_import = time_of_import
    @file_name = file_name
    n = Order.where('created_at > ?',$redis.get("last_order_#{tenant}")).count rescue 0
    @after_import_count = $redis.get("total_orders_#{tenant}").to_i + n
    time_zone = GeneralSetting.last.time_zone.to_i
    time_of_import_tz =  @time_of_import + time_zone
    orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")

    log = {"Time_Stamp_Tenant_TZ" => "#{time_of_import_tz}","Time_Stamp_UTC" => "#{@time_of_import}" , "Tenant" => "#{Apartment::Tenant.current}","Name_of_imported_file" => "#{@file_name}","Orders_in_file" => "#{orders.count}".to_i, "New_orders_imported" => "#{$redis.get("new_order_#{tenant}")}".to_i, "Existing_orders_updated" =>"#{$redis.get("update_order_#{tenant}")}".to_i , "Existing_orders_skipped" => "#{$redis.get("skip_order_#{tenant}")}".to_i, "Orders_in_GroovePacker_before_import" => "#{$redis.get("total_orders_#{tenant}")}".to_i, "Orders_in_GroovePacker_after_import" =>"#{@after_import_count}".to_i }
    summary = CsvImportSummary.find_or_create_by(log_record: log.to_json)
    summary.file_name =  @file_name
    summary.import_type = "Order"
    summary.save
  end

  def send_activity_log
    store_id = "complete"
    current_tenant = Apartment::Tenant.current
    header = "Tenant,Event,Time(EST),Store Type,User Name\n"
    file_data = header
    
    Tenant.find_each do |tenant|
    Apartment::Tenant.switch!(tenant.name)
    file_data +=
      Ahoy::Event
      .where('time > ?', Time.now.ago(7.days))
      .reduce('') do |data, record|
        properties = record.properties
        data += "#{properties['tenant']},#{properties['title']},"
        data += "#{record.time.in_time_zone('EST').strftime('%e %b %Y %H:%M:%S %p')},"
        data += "#{Store.where(id: properties['store_id']).first.try(:store_type)},"
        data += "#{User.where(id: properties['user_id']).first.try(:name)}\n"
      end
    end

    GroovS3.create_csv(current_tenant, 'activity_log', store_id, file_data, :public_read)
    url = GroovS3.find_csv(current_tenant, 'activity_log', store_id).url
    CsvExportMailer.send_csv(url).deliver
  end

  def send_activity_log_v2(params)
    store_id = "complete"
    current_tenant = Apartment::Tenant.current
    header = ['Tenant Name', 'Timestamp', 'Event', 'User', 'Orders/Products Involved', 'Elapsed Time', 'Rate (orders or products/sec)', 'Object Id', 'Saved Changes']
    file_data = header
    params = params.with_indifferent_access
    tenants_list = params[:select_all] ? Tenant.all : Tenant.where(name: params[:tenant_names])

    tenants_list.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      file_data = CSV.generate do |csv|
        csv << header if csv.count.eql? 0
        ahoy_events = Ahoy::Event.where('time > ?', Time.now.ago(7.days)).version_2
        ahoy_events.each do |record|
          properties = record.properties
          csv << [properties['tenant'], record.time.in_time_zone('EST').strftime('%e %b %Y %H:%M:%S %p'), properties['title'], properties['username'], (properties['objects_involved_count'] ? properties['objects_involved_count'].to_s + ' = [' + properties['objects_involved'].to_s.gsub(/\"/, '\'').gsub(/[\[\]]/, '') + ']' : '' rescue nil), properties['elapsed_time'] ? Time.at(properties['elapsed_time']).utc.strftime("%H:%M:%S") : '', properties['object_per_sec'], properties['object_id'], properties['changes']]
        end
      end
    end

    GroovS3.create_csv(current_tenant, 'activity_log_v2', store_id, file_data, :public_read)
    url = GroovS3.find_csv(current_tenant, 'activity_log_v2', store_id).url
    CsvExportMailer.send_csv(url).deliver
  end

  def send_tenant_log
    headers = [ "Tenant Name", "Tenant Notes","Number of Users", "Number of Active Users(in tenant)" , "Number of Products", "Stipe Products Count" ," GP Plan Price","Stripe Plan Price", "Last Stripe Charge","Stripe Charge in last 30 days", "QTY Scanned in last 30", "Is Delinquent", "Admintools URL","Stripe URL", "Start Date", "Billing date" ]
    data = CSV.generate do |csv|
      csv << headers if csv.count.eql? 0
      Subscription.order(:tenant_id).where("status = ? AND tenant_name NOT LIKE ? ", "completed", "%deleted%").each do |sub|
          begin
            t = Tenant.where(name: "#{sub.tenant_name}").last
            if t.present? && t.test_tenant_toggle == false
              Apartment::Tenant.switch! "#{sub.tenant_name}"
              tenant_id = Tenant.find_by_name("#{sub.tenant_name}").id
              access_restriction, tenant_user, product_count, scanned_orders = get_tenant_details("#{sub.tenant_name}") 
              customer = Stripe::Customer.retrieve("#{sub.stripe_customer_id}") rescue nil
              subscription = customer.subscriptions.retrieve("#{sub.customer_subscription_id}")  rescue nil
              total_product =  Stripe::SubscriptionItem.list(subscription: "#{sub.customer_subscription_id}").count rescue nil
              if customer.present? 
                last_stripe_amount = (customer.charges.first.amount / 100) rescue 0
                billing_date = DateTime.strptime("#{customer.charges.first.created}",'%s') rescue nil 
                is_delinquent = customer.delinquent == true ? "delinquent" : "current"
              end
              unless billing_date.nil?
                charge_in_30_days = ((Time.now - 30.days)..Time.now).cover?(billing_date) ?  1 : 0
                charge_in_30_days = 0  if customer.charges.first.status == "failed"
              end
              sub_amount = (sub.amount.to_f / 100) rescue 0   
              val = '*' if sub_amount == 0 || (sub_amount != (access_restriction.try(:num_users) * 50).to_f )
              stripe_amount = 0    
              (subscription.try(:items) || []).each do |item|
                stripe_amount =  stripe_amount + item.plan["amount"]
              end  
              stripe_amount = (stripe_amount.to_f / 100) rescue 0  
              val1 = '**'  if sub_amount != stripe_amount
              csv << ["#{sub.tenant_name}","#{t.note}","#{access_restriction.try(:num_users)}","#{tenant_user}", "#{product_count}" ,"#{total_product}","#{sub_amount}#{val}","#{stripe_amount}#{val1}","#{last_stripe_amount}", "#{charge_in_30_days}","#{scanned_orders}","#{is_delinquent}",  "https://scadmintools.groovepacker.com/#/admin_tools/tenant/1/#{tenant_id}","https://dashboard.stripe.com/customers/#{sub.try(:stripe_customer_id)}", "#{sub.created_at}", "#{billing_date}"]
            end
          rescue Exception => e
            Rollbar.error(e, e.message)
          end  
      end
    end 
    url = GroovS3.create_public_csv("admintools", 'subscription',Time.now.to_i, data).url
    StripeInvoiceEmail.send_tenant_details(url).deliver
  end

  def get_tenant_details(tenant)
    Apartment::Tenant.switch! tenant
    access_restriction = AccessRestriction.order("created_at").last
    tenant_user = (User.where(is_deleted: false, active: true).count - 1 )
    product_sku_count = Product.all.count
    if product_sku_count < 10000
      product_count = product_sku_count 
    elsif (product_sku_count > 10000 || product_sku_count < 100000)
      product_count =   "High SKU"
    elsif product_sku_count > 100000
      product_count = "Double High SKU"
    end
    scanned_orders = Order.where("status = ?  AND scanned_on > ?", "scanned", Time.now() - 30.days ).count
    return access_restriction, tenant_user, product_count, scanned_orders 
  end
end
