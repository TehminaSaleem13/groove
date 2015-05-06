class ExportSetting < ActiveRecord::Base
  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
   :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
   :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun, 
   :last_exported, :export_orders_option, :order_export_type, :order_export_email 

  # after_save :send_export_email
  after_save :scheduled_export

  def scheduled_export
    result = Hash.new
    changed_hash = self.changes
    if self.auto_email_export && !changed_hash[:time_to_send_export_email].nil?
      if self.should_export_orders_today
        job_scheduled = false
        date = DateTime.now
        general_settings = GeneralSetting.all.first
        while !job_scheduled do
          job_scheduled = general_settings.schedule_job(date, 
            self.time_to_send_export_email,'export_order')
          date = DateTime.now + 1.day
        end
      end
    end
  end

  def should_export_orders_today
    day = DateTime.now.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def should_export_orders(date)
    day = date.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  # def send_export_email
  # 	changed_hash = self.changes
  #   logger.info changed_hash
  #   if self.auto_email_export && !changed_hash['time_to_send_export_email'].nil?
  #     if self.should_export_orders_today
  #       job_scheduled = false
  #       date = DateTime.now
  #       while !job_scheduled do
  #         job_scheduled = self.schedule_job(date, 
  #           self.time_to_send_export_email)
  #         date = DateTime.now + 1.day
  #       end
  #     end
  #   end
  # end

  # def schedule_job (date, time)
  #   job_scheduled = false
  #   run_at_date = date.getutc
  #   run_at_date = run_at_date.change({:hour => time.hour, 
  #     :min => time.min, :sec => time.sec})
  #   time_diff = ((run_at_date - DateTime.now.getutc) * 24 * 60 * 60).to_i
  #   logger.info time_diff
  #   if time_diff > 0
  #     tenant = Apartment::Tenant.current_tenant
  #     Delayed::Job.where(queue: "order_export_email_scheduled_#{tenant}").destroy_all
  #     #LowInventoryLevel.notify(self,tenant).deliver
  #     logger.info 'inserting delayed job'
  #     ExportOrder.delay(:run_at => time_diff.seconds.from_now,:queue => "order_export_email_scheduled_#{tenant}").export(self,tenant)
  #     # ExportOrder.export(self,tenant)
  #     job_scheduled = true
  #   end
  #   job_scheduled
  # end

  def export_data
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    start_time = nil
    end_time = nil
    if true
      if self.export_orders_option == 'on_same_day'
        start_time = Time.zone.now.beginning_of_day
      else
        start_time = self.last_exported
      end
      if start_time.nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      else
        serials = OrderSerial.where(created_at: start_time..Time.now)
        puts "serials:  " + serials.inspect
        filename = 'groove-order-serials-'+Time.now.to_s+'.csv'

        row_map = {
            :order_date =>'',
            :order_number => '',
            :barcode_with_serial => '',
            :barcode =>'',
            :serial =>'',
            :primary_sku =>'',
            :product_name=>'',
            :packing_user =>'',
            :order_item_count => '',
            :scanned_date =>'',
            :warehouse_name =>''
        }
        CSV.open("#{Rails.root}/public/csv/#{filename}","w") do |csv|
          csv << row_map.keys

          serials.each do |serial|
            single_row = row_map.dup
            single_row[:order_number] = serial.order.increment_id
            single_row[:order_date] = serial.order.order_placed_time
            single_row[:scanned_date] = serial.order.scanned_on
            packing_user = nil
            packing_user = User.find(serial.order.packing_user_id) unless serial.order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
              single_row[:warehouse_name] =  serial.product.primary_warehouse.inventory_warehouse.name unless serial.product.primary_warehouse.nil? || serial.product.primary_warehouse.inventory_warehouse.nil?
            end
            single_row[:serial] = serial.serial
            single_row[:product_name] = serial.product.name
            single_row[:primary_sku] =  serial.product.primary_sku
            single_row[:barcode] =  serial.product.primary_barcode
            single_row[:barcode_with_serial] = serial.product.primary_barcode
            single_row[:order_item_count] = serial.order.get_items_count

            csv << single_row.values
          end
        end

      end
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to view order serials')
    end

    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end
    filename
    # data
    # send_data data,
    #   :type => 'text/csv; charset=iso-8859-1; header=present',
    #   :disposition => "attachment; filename=users.csv"
    # respond_to do |format|
    #   format.html # show.html.erb
    #   format.csv { send_data  data, :type => 'text/csv', :filename => filename }
    # end
  end
end
