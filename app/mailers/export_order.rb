class ExportOrder < ActionMailer::Base
  default from: "app@groovepacker.com"

  def export(tenant)
    Apartment::Tenant.switch(tenant)
    export_settings = ExportSetting.first
    begin
      @counts = get_order_counts(export_settings) if export_settings.export_orders_option == 'on_same_day'
      filename = export_settings.export_data(tenant)
      @tenant_name = tenant    
      url = GroovS3.find_export_csv(tenant, filename)
      # file_locatin = "#{Rails.root}/public/csv/#{filename}"
      @csv_data = []
      file_data = Net::HTTP.get(URI.parse(url)) rescue []
      file_data = file_data.split("\n")
      file_data.each {|row| @csv_data << row.split(",")}
      # @csv_data = Net::HTTP.get(URI.parse(url)) rescue []
      @csv_data.try(:first).try(:each_with_index) do |value, index|
        case value
        when 'order_number'
          @order_number = index
        when 'scanned_by_status_change'
          @scanned_by_status_change = index
        end
      end
      attachments["#{filename}"] = Net::HTTP.get(URI.parse(url)) rescue nil
      mail to: export_settings.order_export_email,
           subject: "GroovePacker Order Export Report"
      #import_orders_obj = ImportOrders.new
      #import_orders_obj.reschedule_job('export_order', tenant)
      #File.delete(file_locatin) rescue nil
    rescue => e
      ExportOrder.failed_export(e).deliver      
    end
  end

  def failed_export(exception)
    export_settings = ExportSetting.first
    maunual_or_auto = export_settings.manual_export ? "Manual" : "Auto" 
    @exception = exception
    mail to: export_settings.order_export_email, subject: "[#{Apartment::Tenant.current}] [#{Rails.env}] #{maunual_or_auto} Order Export Failed"
  end

  def get_order_counts(export_settings)
    result = {}
    if export_settings.manual_export
      day_begin, end_time = export_settings.send(:set_start_and_end_time)  
    else
      day_begin = Time.now.beginning_of_day
      end_time = Time.now.end_of_day
    end
    scanned_orders = Order.where("scanned_on >= ? and scanned_on <= ?", day_begin, end_time)
    result['imported'] = Order.where("created_at >= ? and created_at <= ?", day_begin, end_time).size
    result['scanned'] = scanned_orders.size
    result['unscanned'] = Order.where("created_at >= ? and created_at <= ? and scanned_on >= ? and scanned_on <= ?", day_begin, end_time, day_begin, end_time).count
    result['item_scanned'] = scanned_orders.joins(:order_items).count
    result['scanned_manually'] = Order.where("scanned_on >= ? and scanned_on <= ? and scanned_by_status_change = ?", day_begin, end_time, true).size
    result['awaiting'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'awaiting').size
    result['onhold'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'onhold').size
    result['cancelled'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'cancelled').size
    result['service_issue'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'serviceissue').size
    # result['total'] = result['imported'] + result['scanned']
    result
  end
end
