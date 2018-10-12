class DailyPacked
  def send_daily_pack_csv(tenant)
    require 'csv'
    Apartment::Tenant.switch(tenant)
    export_setting = ExportSetting.first
    duration = export_setting.daily_packed_export_type.to_i
    email = export_setting.daily_packed_email
    processing = export_setting.processing_time
    all_dates = []
    headers = ["OrderNumber", "ShipDate", "WeekDay","Status", " Tracking Number" ]
    data = CSV.generate do |csv|
      csv << headers if csv.count.eql? 0
      orders = Order.where('order_placed_time > ? AND status != ?', Time.now() - duration.days, "scanned")
      begin
        orders.each do |order|
          order_date = order.order_placed_time + processing.day
          order_day = order_date.strftime("%A")
          if order.status == "onhold"
            csv << ["#{order.increment_id}","#{order_date}","#{order_day}","Action Required","#{order.tracking_num}\f"]
          else
            csv << ["#{order.increment_id}","#{order_date}","#{order_day}","#{order.status}","#{order.tracking_num}\f"]
          end 
        end
      rescue 
      end
    end
    url = GroovS3.create_public_csv(tenant, 'order',Time.now.to_i, data).url
    CsvExportMailer.send_daily_packed(url,tenant).deliver
  end
end