class ExportOrder < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def export(tenant)
    Apartment::Tenant.switch(tenant)
    # @products_list = get_entire_list
    export_settings = ExportSetting.all.first
    # @data = export_settings.export_data
    # puts "@data: " + @data.inspect
    @counts = get_order_counts
    # send_data @data,
    #   :type => 'text/csv; charset=iso-8859-1; header=present',
    #   :disposition => "attachment; filename=users.csv"
    filename = export_settings.export_data
    attachments["#{filename}"] = File.read("#{Rails.root}/public/csv/#{filename}")
    # encoded_content = SpecialEncode(File.read(export_settings.export_data))
    # attachments['filename.jpg'] = {
    #   mime_type: 'text/csv',
    #   encoding: 'SpecialEncoding',
    #   content: encoded_content
    # }
  	mail to: export_settings.order_export_email,
  		subject: "GroovePacker Order Export Report"

    # reschedule(tenant)
    import_orders_obj = ImportOrders.new
    import_orders_obj.reschedule_job('export_order',tenant)
    File.delete("#{Rails.root}/public/csv/#{filename}")
  end

  def reschedule(tenant)
    date = DateTime.now
    date = date + 1.day
    job_scheduled = false
    export_settings = ExportSetting.all.first
    while !job_scheduled do
      should_schedule_job = export_settings.should_export_orders(date)
      time = export_settings.time_to_send_export_email

      if should_schedule_job
        job_scheduled = export_settings.schedule_job(date,
          time)
      else
        date = date + 1.day
      end
    end
  end

  # def export_data(export_settings)
  #   require 'csv'
  #   result = Hash.new
  #   result['status'] = true
  #   result['messages'] = []
  #   start_time = nil
  #   end_time = nil
  #   if true
  #     if export_settings.export_orders_option == 'on_same_day'
  #       start_time = Time.zone.now.beginning_of_day
  #     else
  #       start_time = export_settings.last_exported
  #     end
  #     if start_time.nil?
  #       result['status'] = false
  #       result['messages'].push('We need a start and an end time')
  #     else
  #       serials = OrderSerial.where(created_at: start_time..Time.now)
  #       puts "serials:  " + serials.inspect
  #       filename = 'groove-order-serials-'+Time.now.to_s+'.csv'
  #       row_map = {
  #           :order_date =>'',
  #           :order_number => '',
  #           :barcode_with_serial => '',
  #           :barcode =>'',
  #           :serial =>'',
  #           :primary_sku =>'',
  #           :product_name=>'',
  #           :packing_user =>'',
  #           :order_item_count => '',
  #           :scanned_date =>'',
  #           :warehouse_name =>''
  #       }
  #       data = CSV.generate do |csv|
  #         csv << row_map.keys

  #         serials.each do |serial|
  #           single_row = row_map.dup
  #           single_row[:order_number] = serial.order.increment_id
  #           single_row[:order_date] = serial.order.order_placed_time
  #           single_row[:scanned_date] = serial.order.scanned_on
  #           packing_user = nil
  #           packing_user = User.find(serial.order.packing_user_id) unless serial.order.packing_user_id.blank?
  #           unless packing_user.nil?
  #             single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
  #             single_row[:warehouse_name] =  serial.product.primary_warehouse.inventory_warehouse.name unless serial.product.primary_warehouse.nil? || serial.product.primary_warehouse.inventory_warehouse.nil?
  #           end
  #           single_row[:serial] = serial.serial
  #           single_row[:product_name] = serial.product.name
  #           single_row[:primary_sku] =  serial.product.primary_sku
  #           single_row[:barcode] =  serial.product.primary_barcode
  #           single_row[:barcode_with_serial] = serial.product.primary_barcode
  #           single_row[:order_item_count] = serial.order.get_items_count

  #           csv << single_row.values
  #         end
  #       end

  #     end
  #   else
  #     result['status'] = false
  #     result['messages'].push('You do not have enough permissions to view order serials')
  #   end

  #   unless result['status']
  #     data = CSV.generate do |csv|
  #       csv << result['messages']
  #     end
  #     filename = 'error.csv'
  #   end
  #   data
  #   # respond_to do |format|
  #   #   format.html # show.html.erb
  #     # format.csv { send_data  data, :type => 'text/csv', :filename => filename }
  #   # end
  # end

  def get_order_counts
    result = Hash.new
    result['imported'] = Order.where("created_at >= ?", Time.zone.now.beginning_of_day).size
    result['scanned'] = Order.where("created_at >= ? and status = ?", Time.zone.now.beginning_of_day,'scanned').size
    result['awaiting'] = Order.where("created_at >= ? and status = ?", Time.zone.now.beginning_of_day,'awaiting').size
    result['onhold'] = Order.where("created_at >= ? and status = ?", Time.zone.now.beginning_of_day,'onhold').size
    result['cancelled'] = Order.where("created_at >= ? and status = ?", Time.zone.now.beginning_of_day,'cancelled').size
    result
  end
end
