class ExportOrder < ActionMailer::Base
  default from: "app@groovepacker.com"

  def export(tenant)
    Apartment::Tenant.switch(tenant)
    export_settings = ExportSetting.first
    
    @counts = get_order_counts if export_settings.export_orders_option == 'on_same_day'
    
    filename = export_settings.export_data
    @tenant_name = tenant
    file_locatin = "#{Rails.root}/public/csv/#{filename}"
    @csv_data = CSV.read(file_locatin)
    @csv_data.first.each_with_index do |value, index|
      case value
      when 'order_number'
        @order_number = index
      when 'scanned_by_status_change'
        @scanned_by_status_change = index
      end
    end

    attachments["#{filename}"] = File.read(file_locatin)
    mail to: export_settings.order_export_email,
         subject: "GroovePacker Order Export Report"
    import_orders_obj = ImportOrders.new
    import_orders_obj.reschedule_job('export_order', tenant)
    File.delete(file_locatin)
  end

  def get_order_counts
    result = {}
    day_begin = Time.now.beginning_of_day
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
