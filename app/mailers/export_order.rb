class ExportOrder < ActionMailer::Base
  default from: "app@groovepacker.com"

  def export(tenant)
    Apartment::Tenant.switch!(tenant)
    Time.use_zone(GeneralSetting.new_time_zone) do
      export_settings = ExportSetting.first
      begin
        @status = false
        manual_export = export_settings.manual_export
        @counts = get_order_counts(export_settings) if export_settings.export_orders_option == 'on_same_day'
        export_settings.manual_export = manual_export
        if !export_settings.manual_export
          @day_begin, @end_time = export_settings.send(:set_start_and_end_time)
          @status = true
        end
        filename = export_settings.export_data(tenant)
        @tenant_name = tenant
        url = GroovS3.find_export_csv(tenant, filename)
        # file_locatin = "#{Rails.root}/public/csv/#{filename}"
        @csv_data = []
        file_data = Net::HTTP.get(URI.parse(url)) rescue []
        file_data = CSV.parse(file_data)
        file_data.each do |row|
          @csv_data << row
        end
        # @csv_data = Net::HTTP.get(URI.parse(url)) rescue []
        @csv_data.try(:first).try(:each_with_index) do |value, index|
          case value
          when 'order_number'
            @order_number = index
          when 'scanned_by_status_change'
            @scanned_by_status_change = index
          end
        end
        FTP::FtpConnectionManager.get_instance(Store.find_by(store_type: 'system')).upload_file(url, filename) rescue nil if export_settings.auto_ftp_export
        attachments["#{filename}"] = Net::HTTP.get(URI.parse(url)) rescue nil
        mail to: export_settings.order_export_email,
            subject: "GroovePacker #{tenant} Order Export Report"
        #import_orders_obj = ImportOrders.new
        #import_orders_obj.reschedule_job('export_order', tenant)
        #File.delete(file_locatin) rescue nil
      rescue => e
        ExportOrder.failed_export(e).deliver
      end
    end
  end

  def not_scheduled_emails(tenants, scheduled_tenants)
    @tenants = tenants
    @scheduled_tenants = scheduled_tenants
    mail to: ENV["UNSCANNED_ORDERS_EMAILS"], subject: "[#{Rails.env}] Not queued/ queued tenants"
  end

  def failed_export(exception)
    export_settings = ExportSetting.first
    maunual_or_auto = export_settings.manual_export ? "Manual" : "Auto"
    @exception = exception
    mail to: export_settings.order_export_email, subject: "[#{Apartment::Tenant.current}] [#{Rails.env}] #{maunual_or_auto} Order Export Failed"
  end

  def get_order_counts(export_settings)
    result = {}
    day_begin, end_time = export_settings.send(:set_start_and_end_time)
    ExportSetting.update_all(manual_export: false)
    result['imported'] = Order.where("created_at >= ? and created_at <= ?", day_begin, end_time).size
    result['scanned'] = Order.where("scanned_on >= ? and scanned_on <= ?", day_begin, end_time).size
    result['clicked_scanned_items'] = Order.includes(:order_items).where("scanned_on >= ? and scanned_on <= ?", day_begin, end_time).map(&:order_items).flatten.map(&:clicked_qty).sum
    result['unscanned'] = result['imported'] - Order.where("created_at >= ? and created_at <= ? and scanned_on >= ? and scanned_on <= ?", day_begin, end_time, day_begin, end_time).size
    result['item_scanned'] = Order.where("scanned_on >= ? and scanned_on <= ?", day_begin, end_time).size
    result['scanned_manually'] = Order.where("scanned_on >= ? and scanned_on <= ? and scanned_by_status_change = ?", day_begin, end_time, true).size
    result['awaiting'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'awaiting').size
    result['onhold'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'onhold').size
    result['cancelled'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'cancelled').size
    result['service_issue'] = Order.where("created_at >= ? and created_at <= ? and status = ?", day_begin, end_time, 'serviceissue').size
    result['incorrect_scans'] = Order.where("scanned_on >= ? and scanned_on <= ?", day_begin, end_time).pluck(:inaccurate_scan_count).sum
    # result['total'] = result['imported'] + result['scanned']
    result
  end
end
