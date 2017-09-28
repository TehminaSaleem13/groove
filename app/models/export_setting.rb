class ExportSetting < ActiveRecord::Base
  include ExportData

  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
                  :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
                  :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun,
                  :last_exported, :export_orders_option, :order_export_type, :order_export_email,
                  :start_time, :end_time, :manual_export, :auto_stat_email_export, :time_to_send_stat_export_email,
                  :send_stat_export_email_on_mon, :send_stat_export_email_on_tue, :send_stat_export_email_on_wed,
                  :send_stat_export_email_on_thu, :send_stat_export_email_on_fri, :send_stat_export_email_on_sat,
                  :send_stat_export_email_on_sun, :stat_export_type, :stat_export_email

  after_save :scheduled_export

  def scheduled_export
    if auto_stat_email_export_with_changed_hash
      schedule_job("stat_export", time_to_send_stat_export_email)
    else
      destroy_stat_export_email_scheduled
    end
    if auto_email_export_with_changed_hash
      schedule_job("export_order", time_to_send_export_email)
    else
      destroy_order_export_email_scheduled
    end
  end

  def should_export_orders_today
    day = DateTime.now.strftime('%a')
    # Returns True/False
    send("send_export_email_on_#{day.downcase}")
  end

  def should_export_orders(date)
    day = date.strftime('%a')
    # Returns True/False
    send("send_export_email_on_#{day.downcase}")
  end

  def should_stat_export_orders(date)
    day = date.strftime('%a')
    # Returns True/False
    send("send_stat_export_email_on_#{day.downcase}")
  end

  def calculate_row_data(single_row, order_item)
    order = order_item.order
    update_single_row(single_row, order)
    update_single_row_for_packing_user(single_row, order_item, order)
    update_single_row_for_product_info(single_row, order_item)
    single_row
  end

  def export_data(tenant=nil)
    require 'csv'
    Apartment::Tenant.switch (tenant)
    # result = set_result_hash
    start_time, end_time = set_start_and_end_time
    return with_error_filename if start_time.blank?
    
    orders = Order.where(scanned_on: start_time..end_time)

    ExportSetting.update_all(:last_exported => Time.zone.now)
    filename = generate_file_name
    if order_export_type == 'do_not_include'
      do_export_if_orders_not_included(orders, filename)
    else
      do_export_with_orders(orders, filename, tenant)
    end
    filename
  end

  private

  def auto_email_export_with_changed_hash
    auto_email_export &&
      changes[:time_to_send_export_email].present? &&
      order_export_email.present?
  end

  def auto_stat_email_export_with_changed_hash
    auto_stat_email_export && changes[:time_to_send_stat_export_email].present? && stat_export_email.present?
  end

  def schedule_job(type, time)
    job_scheduled = false
    date = DateTime.now
    general_settings = GeneralSetting.all.first
    7.times do
      job_scheduled = general_settings.schedule_job(
        date, time, type
      )
      date += 1.day
      break if job_scheduled
    end
  end

  def destroy_order_export_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where("queue =? && run_at < ?", "order_export_email_scheduled_#{tenant}", Time.now()).destroy_all
    # Delayed::Job.where(
    #   queue: "order_export_email_scheduled_#{tenant}"
    # ).destroy_all
  end

  def destroy_stat_export_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where("queue =? && run_at < ?", "generate_stat_export_#{tenant}", Time.now()).destroy_all
  end

  def update_single_row(single_row, order)
    single_row[:order_number] = order.increment_id
    single_row[:order_date] = order.order_placed_time
    single_row[:scanned_date] = (order.scanned_on + GeneralSetting.last.time_zone.to_i).strftime("%Y-%m-%d %I:%M %p") rescue order.scanned_on.strftime("%Y-%m-%d %I:%M %p")
    single_row[:address1] = order.address_1
    single_row[:address2] = order.address_2
    single_row[:city] = order.city
    single_row[:state] = order.state
    single_row[:zip] = order.postcode
    single_row[:customer_name] = order.customer_name
  end

  def update_single_row_for_packing_user(single_row, order_item, order)
    packing_user = User.where(id: order.packing_user_id).first
    return if packing_user.blank?
    single_row[:packing_user] = "#{packing_user.name} (#{packing_user.username})"
    single_row[:warehouse_name] = order_item.product.primary_warehouse
                                  .try(:inventory_warehouse).try(:name)
  end
  def update_single_row_for_product_info(single_row, order_item)
    product = order_item.product
    single_row[:barcode] = product.primary_barcode

    if product.is_kit == 1
      single_row[:kit_name] = product.name
    else
      single_row[:product_name] = product.name
    end

    single_row[:primary_sku] = product.primary_sku
    single_row[:item_sale_price] = order_item.price
  end

  def set_start_and_end_time
    start_time = self.start_time.beginning_of_day - GeneralSetting.last.time_zone.to_i rescue (DateTime.now-1.days)
    end_time = self.end_time.end_of_day - GeneralSetting.last.time_zone.to_i rescue DateTime.now
    return [start_time, end_time] if manual_export
    if export_orders_option.eql? 'on_same_day'
      job_time = Delayed::Job.where(queue: "order_export_email_scheduled_#{Apartment::Tenant.current}").map(&:locked_at).compact[0]
      job_time = DateTime.now.utc if job_time.blank?
      start_time = job_time - time_to_send_export_email.strftime("%H").to_i.hours - time_to_send_export_email.strftime("%M").to_i.minutes
      end_time = job_time
      # time = time_to_send_export_email.strftime("%H:%M")
      # seconds = Time.parse(time).seconds_since_midnight
      # start_time = ((Time.now.utc.beginning_of_day - 1.day) + seconds).end_of_day - GeneralSetting.last.time_zone.to_i
      # start_time = Time.now+GeneralSetting.last.time_zone.to_i
    else
      last_exported || '2000-01-01 00:00:00'
      end_time = Time.zone.now
    end
    # end_time = Time.now.utc.beginning_of_day + seconds - GeneralSetting.last.time_zone.to_i
    # start_time = same_day_or_last_exported(start_time)
    [start_time, end_time]
  end

  def same_day_or_last_exported(start_time)
    if export_orders_option.eql? 'on_same_day'
      Time.zone.now.beginning_of_day
    else
      last_exported || '2000-01-01 00:00:00'
    end
  end

  def with_error_filename
    # result['status'] = false
    # result['messages'].push('We need a start and an end time')
    CSV.generate do |csv|
      csv << result['messages']
    end
    'error.csv'
  end

  def generate_file_name
    "groove-order-export-#{Time.now}.csv"
  end

  def file_path(filename)
    "#{Rails.root}/public/csv/#{filename}"
  end

  def do_export_if_orders_not_included(orders, filename)
    row_map = generate_row_mapping
    data = CSV.generate do |csv|
      csv << row_map.keys
      orders.each do |order|
        single_row = update_single_row_with_order_data(row_map, order)
        assign_packing_user(single_row, order)
        single_row[:click_scanned_qty] = calculate_clicked_qty(order)
        csv << single_row.values
      end
    end
    tenant = Apartment::Tenant.current
    GroovS3.create_export_csv(tenant, filename, data)
    #url = GroovS3.find_export_csv(tenant, filename)
    #ExportOrder.export(tenant).deliver if ExportSetting.first.manual_export == true
  end

  def generate_row_mapping
    {
      order_date: '',
      order_number: '',
      scanned_qty: '',
      packing_user: '',
      scanned_date: '',
      click_scanned_qty: ''
    }
  end

  def update_single_row_with_order_data(row_map, order)
    single_row = row_map.dup
    single_row[:order_number] = order.increment_id
    single_row[:scanned_qty] = order.scanned_items_count
    single_row[:order_date] = order.order_placed_time
    single_row[:scanned_date] = (order.scanned_on + GeneralSetting.last.time_zone.to_i).strftime("%Y-%m-%d %I:%M %p") rescue order.scanned_on.strftime("%Y-%m-%d %I:%M %p")
    single_row
  end

  def assign_packing_user(single_row, order)
    packing_user = User.where(id: order.packing_user_id).first
    return unless packing_user
    single_row[:packing_user] = "#{packing_user.name} ( #{packing_user.username} )"
  end

  def calculate_clicked_qty(order)
    order.order_items.map(&:clicked_qty).sum
  end
end
