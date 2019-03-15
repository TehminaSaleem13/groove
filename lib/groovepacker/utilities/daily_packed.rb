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
        get_data_into_csv(csv,orders,processing)
      rescue 
      end
    end
    create_csv_and_send_email(tenant, data)
  end

  def send_csv_daily_pack(params,tenant)
    require 'csv'
    Apartment::Tenant.switch(tenant)
    tenant = Apartment::Tenant.current
    processing = ExportSetting.first.processing_time
    headers = ["OrderNumber", "ShipDate", "WeekDay","Status", " Tracking Number" ]
    all_dates = params[:dashboard][:_json]
    data = CSV.generate do |csv|
      csv << headers if csv.count.eql? 0
      all_dates.each do |date|
        new_date =  DateTime.parse(date)
        new_date =  new_date - processing if  processing != 0
        orders = Order.select("order_placed_time, status, tracking_num, increment_id").where('order_placed_time >= ? AND order_placed_time <= ? AND status != ?', new_date.beginning_of_day, new_date.end_of_day, "scanned")
        get_data_into_csv(csv,orders,processing)
      end
    end
    create_csv_and_send_email(tenant, data)
  end

  def get_data_into_csv(csv, orders, processing)
    orders.each do |order|
      order_date = order.order_placed_time + processing.day
      order_day = order_date.strftime("%A")
      if order.status == "onhold"
        csv << ["#{order.increment_id}","#{order_date}","#{order_day}","Action Required","#{order.tracking_num}\f"]
      else
        csv << ["#{order.increment_id}","#{order_date}","#{order_day}","#{order.status}","#{order.tracking_num}\f"]
      end 
    end
  end

  def create_csv_and_send_email(tenant, data)
    url = GroovS3.create_public_csv(tenant, 'order',Time.now.to_i, data).url
    CsvExportMailer.send_daily_packed(url,tenant).deliver
  end
end