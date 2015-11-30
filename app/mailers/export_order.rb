class ExportOrder < ActionMailer::Base
  default from: "app@groovepacker.com"

  def export(tenant)
    Apartment::Tenant.switch(tenant)
    export_settings = ExportSetting.all.first
    if export_settings.export_orders_option == 'on_same_day'
      @counts = get_order_counts
    else
      @counts = nil
    end
    filename = export_settings.export_data
    @tenant_name = tenant
    @csv_data = CSV.read("#{Rails.root}/public/csv/#{filename}")
    @csv_data.first.each_with_index do |value, index|
      if value == 'order_number'
        @order_number = index
      end
    end

    attachments["#{filename}"] = File.read("#{Rails.root}/public/csv/#{filename}")
    mail to: 'aitashish173@gmail.com', #export_settings.order_export_email,
         subject: "GroovePacker Order Export Report"
    import_orders_obj = ImportOrders.new
    import_orders_obj.reschedule_job('export_order', tenant)
    File.delete("#{Rails.root}/public/csv/#{filename}")
  end

  def get_order_counts
    result = Hash.new
    result['imported'] = Order.where("created_at >= ?", Time.now.beginning_of_day).size
    result['scanned'] = Order.where("scanned_on >= ?", Time.now.beginning_of_day).size
    result['awaiting'] = Order.where("created_at >= ? and status = ?", Time.now.beginning_of_day, 'awaiting').size
    result['onhold'] = Order.where("created_at >= ? and status = ?", Time.now.beginning_of_day, 'onhold').size
    result['cancelled'] = Order.where("created_at >= ? and status = ?", Time.now.beginning_of_day, 'cancelled').size
    result
  end
end
