# frozen_string_literal: true

class AddLogCsv
  def add_log_csv(tenant, time_of_import, file_name)
    Apartment::Tenant.switch!(tenant)
    @time_of_import = time_of_import
    @file_name = file_name
    n = begin
          Order.where('created_at > ?', $redis.get("last_order_#{tenant}")).count
        rescue StandardError
          0
        end
    @after_import_count = $redis.get("total_orders_#{tenant}").to_i + n
    # time_zone = GeneralSetting.last.time_zone.to_i
    # time_of_import_tz =  @time_of_import + time_zone
    orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")

    log = { 'Time_Stamp_Tenant_TZ' => @time_of_import.to_s, 'Time_Stamp_UTC' => @time_of_import.utc.to_s, 'Tenant' => Apartment::Tenant.current.to_s, 'Name_of_imported_file' => @file_name.to_s, 'Orders_in_file' => orders.count.to_s.to_i, 'New_orders_imported' => $redis.get("new_order_#{tenant}").to_s.to_i, 'Existing_orders_updated' => $redis.get("update_order_#{tenant}").to_s.to_i, 'Existing_orders_skipped' => $redis.get("skip_order_#{tenant}").to_s.to_i, 'Orders_in_GroovePacker_before_import' => $redis.get("total_orders_#{tenant}").to_s.to_i, 'Orders_in_GroovePacker_after_import' => @after_import_count.to_s.to_i }
    summary = CsvImportSummary.find_or_create_by(log_record: log.to_json)
    summary.file_name = @file_name
    summary.import_type = 'Order'
    summary.save
  end

  def send_activity_log
    store_id = 'complete'
    current_tenant = Apartment::Tenant.current
    header = "Tenant,Event,Time(EST),Store Type,User Name\n"
    file_data = header

    Tenant.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      file_data +=
        Ahoy::Event
        .where('time > ?', Time.current.ago(7.days))
        .reduce('') do |data, record|
          properties = record.properties
          data += "#{properties['tenant']},#{properties['title']},"
          data += "#{record.time.in_time_zone('EST').strftime('%e %b %Y %H:%M:%S %p')},"
          data += "#{Store.where(id: properties['store_id']).first.try(:store_type)},"
          data += "#{User.where(id: properties['user_id']).first.try(:name)}\n"
        end
    end

    GroovS3.create_csv(current_tenant, 'activity_log', store_id, file_data, :public_read)
    url = GroovS3.find_csv(current_tenant, 'activity_log', store_id).url.gsub('http:', 'https:')
    CsvExportMailer.send_csv(url).deliver
  end

  def send_activity_log_v2(params)
    store_id = 'complete'
    current_tenant = Apartment::Tenant.current
    header = ['Tenant Name', 'Timestamp', 'Event', 'User', 'Orders/Products Involved', 'Elapsed Time', 'Rate (orders or products/sec)', 'Object Id', 'Saved Changes']
    file_data = header
    params = params.to_unsafe_h.with_indifferent_access
    tenants_list = params[:select_all] ? Tenant.all : Tenant.where(name: params[:tenant_names])

    tenants_list.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      file_data = CSV.generate do |csv|
        csv << header if csv.count.eql? 0
        ahoy_events = Ahoy::Event.version_2.where('time > ?', Time.current.ago(7.days))
        ahoy_events.each do |record|
          properties = record.properties
          csv << [properties['tenant'], record.time.in_time_zone('EST').strftime('%e %b %Y %H:%M:%S %p'), properties['title'], properties['username'], (begin
                                                                                                                                                          properties['objects_involved_count'] ? properties['objects_involved_count'].to_s + ' = [' + properties['objects_involved'].to_s.tr('"', '\'').gsub(/[\[\]]/, '') + ']' : ''
                                                                                                                                                        rescue StandardError
                                                                                                                                                          nil
                                                                                                                                                        end), properties['elapsed_time'] ? Time.at(properties['elapsed_time']).utc.strftime('%H:%M:%S') : '', properties['object_per_sec'], properties['object_id'], properties['changes']]
        end
      end
    end

    GroovS3.create_csv(current_tenant, 'activity_log_v2', store_id, file_data, :public_read)
    url = GroovS3.find_csv(current_tenant, 'activity_log_v2', store_id).url.gsub('http:', 'https:')
    CsvExportMailer.send_csv(url).deliver
  end

  def send_bulk_event_logs(params)
    store_id = 'complete'
    current_tenant = Apartment::Tenant.current
    header = ['Tenant Name', 'Timestamp', 'Event', 'User', 'Data']
    file_data = header
    params = params.to_unsafe_h.with_indifferent_access
    tenants_list = params[:select_all] ? Tenant.all : Tenant.where(name: params[:tenant_names])

    tenants_list.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      file_data = CSV.generate do |csv|
        csv << header if csv.count.eql? 0
        events = EventLog.where('created_at > ?', 90.days.ago)
        events.each do |record|
          csv << [tenant.name, record.created_at.in_time_zone('EST').strftime('%e %b %Y %H:%M:%S %p'), record.message, record.user&.username, record.data]
        end
      end
    end

    GroovS3.create_csv(current_tenant, 'send_bulk_event_logs', store_id, file_data, :public_read)
    url = GroovS3.find_csv(current_tenant, 'send_bulk_event_logs', store_id).url.gsub('http:', 'https:')
    CsvExportMailer.send_bulk_record_csv(url,current_tenant).deliver
  end

  def get_duplicates_order_info(params)
    tenants_list = params[:select_all] ? Tenant.all : Tenant.where(name: params[:tenant_names])
    tenants_list.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)

      dup_order_increment_ids = []
      dup_order_ids = []

      Order.where('created_at > ?', 5.day.ago).group_by(&:increment_id).each do |_key, orders|
        next if orders.count == 1

        scanned_true = ((orders.map(&:status).include? 'scanned') || (orders.map(&:status).include? 'cancelled'))
        if scanned_true
          orders.each do |dup_order|
            dup_order_increment_ids << dup_order.increment_id unless dup_order.status == 'scanned' || dup_order.status == 'cancelled'
            dup_order_ids << dup_order.id unless dup_order.status == 'scanned' || dup_order.status == 'cancelled'
          end
        else
          orders.drop(1).each do |dup_order|
            dup_order_ids << dup_order.id
            dup_order_increment_ids << dup_order.increment_id
          end
        end
      end
      CsvExportMailer.send_duplicates_order_info(tenant.name, dup_order_increment_ids, dup_order_ids).deliver
    end
  end

  def send_tenant_log
    headers = ['Tenant Name', 'Tenant Notes', 'Number of Users', 'Number of Active Users(in tenant)', 'Number of Products', 'Stipe Products Count', ' GP Plan Price', 'Stripe Plan Price', 'Last Stripe Charge', 'Stripe Charge in last 30 days', 'QTY Scanned in last 30', 'Is Delinquent', 'Admintools URL', 'Stripe URL', 'Start Date', 'Billing date']
    data = CSV.generate do |csv|
      csv << headers if csv.count.eql? 0
      Subscription.order(:tenant_id).where('status = ? AND tenant_name NOT LIKE ? ', 'completed', '%deleted%').each do |sub|
        t = Tenant.where(name: sub.tenant_name.to_s).last
        if t.present? && t.test_tenant_toggle == false
          Apartment::Tenant.switch! sub.tenant_name.to_s
          tenant_id = Tenant.find_by_name(sub.tenant_name.to_s).id
          access_restriction, tenant_user, product_count, scanned_orders = get_tenant_details(sub.tenant_name.to_s)
          customer = begin
                         Stripe::Customer.retrieve(sub.stripe_customer_id.to_s)
                     rescue StandardError
                       nil
                       end
          subscription = begin
                             customer.subscriptions.retrieve(sub.customer_subscription_id.to_s)
                         rescue StandardError
                           nil
                           end
          total_product = begin
                               Stripe::SubscriptionItem.list(subscription: sub.customer_subscription_id.to_s).count
                          rescue StandardError
                            nil
                             end
          invoice = begin
                        Stripe::Invoice.retrieve(customer.subscriptions.data.first.latest_invoice.to_s)
                    rescue StandardError
                      nil
                      end
          if customer.present?
            last_stripe_amount = begin
                                     (customer.subscriptions.data.first.plan.amount / 100)
                                 rescue StandardError
                                   0
                                   end
            billing_date = begin
                               DateTime.strptime(invoice.created.to_s, '%s')
                           rescue StandardError
                             nil
                             end
            is_delinquent = customer.delinquent == true ? 'delinquent' : 'current'
          end
          unless billing_date.nil?
            charge_in_30_days = ((Time.current - 30.days)..Time.current).cover?(billing_date) ? true : false
            charge_in_30_days = false if invoice.status != 'paid'
          end
          sub_amount = begin
                           (sub.amount.to_f / 100)
                       rescue StandardError
                         0
                         end
          val = '*' if sub_amount == 0 || (sub_amount != (access_restriction.try(:num_users) * 50).to_f)
          stripe_amount = 0
          (subscription.try(:items) || []).each do |item|
            stripe_amount += item.plan['amount']
          end
          stripe_amount = begin
                              (stripe_amount.to_f / 100)
                          rescue StandardError
                            0
                            end
          val1 = '**' if sub_amount != stripe_amount
          csv << [sub.tenant_name.to_s, t.note.to_s, access_restriction.try(:num_users).to_s, tenant_user.to_s, product_count.to_s, total_product.to_s, "#{sub_amount}#{val}", "#{stripe_amount}#{val1}", last_stripe_amount.to_s, charge_in_30_days.to_s, scanned_orders.to_s, is_delinquent.to_s, "https://scadmintools.groovepacker.com/#/admin_tools/tenant/1/#{tenant_id}", "https://dashboard.stripe.com/customers/#{sub.try(:stripe_customer_id)}", sub.created_at.to_s, billing_date.to_s]
        end
      rescue Exception => e
        Rollbar.error(e, e.message, Apartment::Tenant.current)
      end
    end
    url = GroovS3.create_public_csv('admintools', 'subscription', Time.current.to_i, data).url.gsub('http:', 'https:')
    StripeInvoiceEmail.send_tenant_details(url).deliver
  end

  def get_tenant_details(tenant)
    Apartment::Tenant.switch! tenant
    access_restriction = AccessRestriction.order('created_at').last
    tenant_user = (User.where(is_deleted: false, active: true).count - 1)
    product_sku_count = Product.all.count
    if product_sku_count < 10_000
      product_count = product_sku_count
    elsif product_sku_count > 10_000 || product_sku_count < 100_000
      product_count = 'High SKU'
    elsif product_sku_count > 100_000
      product_count = 'Double High SKU'
    end
    scanned_orders = Order.where('status = ?  AND scanned_on > ?', 'scanned', Time.current - 30.days).count
    [access_restriction, tenant_user, product_count, scanned_orders]
  end
end
