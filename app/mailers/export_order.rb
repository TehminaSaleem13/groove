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
      day_begin = Time.zone.now.beginning_of_day
    end
    result['imported'] = Order.where("created_at >= ?", day_begin).size
    result['scanned'] = Order.where("scanned_on >= ?", day_begin).size
    result['scanned_manually'] = Order.where("scanned_on >= ? and scanned_by_status_change = ?", day_begin, true).size
    result['awaiting'] = Order.where("created_at >= ? and status = ?", day_begin, 'awaiting').size
    result['onhold'] = Order.where("created_at >= ? and status = ?", day_begin, 'onhold').size
    result['cancelled'] = Order.where("created_at >= ? and status = ?", day_begin, 'cancelled').size
    result['total'] = result['imported'] + result['scanned']
    result
  end
end
