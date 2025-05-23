# frozen_string_literal: true

class ExportSetting < ApplicationRecord
  include ExportData
  include AhoyEvent

  # attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
  #                 :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
  #                 :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun,
  #                 :last_exported, :export_orders_option, :order_export_type, :order_export_email,
  #                 :start_time, :end_time, :manual_export, :auto_stat_email_export, :time_to_send_stat_export_email,
  #                 :send_stat_export_email_on_mon, :send_stat_export_email_on_tue, :send_stat_export_email_on_wed,
  #                 :send_stat_export_email_on_thu, :send_stat_export_email_on_fri, :send_stat_export_email_on_sat,
  #                 :send_stat_export_email_on_sun, :stat_export_type, :stat_export_email, :processing_time,
  #                 :daily_packed_email_export, :time_to_send_daily_packed_export_email, :daily_packed_email_on_mon,
  #                 :daily_packed_email_on_tue, :daily_packed_email_on_wed, :daily_packed_email_on_thu, :daily_packed_email_on_fri,
  #                 :daily_packed_email_on_sat, :daily_packed_email_on_sun, :daily_packed_email ,:daily_packed_export_type

  after_save :scheduled_export
  after_commit :log_events

  def log_events
    if saved_changes.present? && saved_changes.keys != ['updated_at']
      track_changes(title: 'Export Settings Changed', tenant: Apartment::Tenant.current,
                    username: User.current.try(:username) || 'GP App', object_id: id, changes: saved_changes)
    end
  end

  def scheduled_export
    if auto_stat_email_export_with_changed_hash
      schedule_job('stat_export', time_to_send_stat_export_email)
    else
      destroy_stat_export_email_scheduled
    end
    if auto_email_export_with_changed_hash
      schedule_job('export_order', time_to_send_export_email)
    else
      destroy_order_export_email_scheduled
    end
    daily_packed_check
  end

  def daily_packed_check
    if auto_email_daily_export_with_changed_hash
      schedule_job('daily_packed', time_to_send_daily_packed_export_email)
    else
      destroy_daily_packed_email_scheduled
    end
  end

  # def should_export_orders_today
  #   day = DateTime.now.in_time_zone.strftime('%a')
  #   # Returns True/False
  #   send("send_export_email_on_#{day.downcase}")
  # end

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

  def should_daily_export_orders(date)
    day = date.strftime('%a')
    send("daily_packed_email_on_#{day.downcase}")
  end

  def calculate_row_data(single_row, order_item, box = nil, order_item_kit = nil)
    order = order_item.order
    update_single_row(single_row, order, box, order_item)
    update_single_row_for_packing_user(single_row, order_item, order)
    update_single_row_for_product_info(single_row, order_item, order_item_kit)
    single_row
  end

  def export_data(tenant = nil)
    require 'csv'
    # Apartment::Tenant.switch! (tenant)
    # result = set_result_hash
    # Time.use_zone(GeneralSetting.new_time_zone) do
    start_time, end_time = set_start_and_end_time
    return with_error_filename if start_time.blank?

    scanned_orders = Order.where(scanned_on: start_time..end_time)
    partially_orders = Order.where(updated_at: start_time..end_time).joins(:order_items).where.not(status: 'scanned').where('order_items.scanned_status =? OR order_items.scanned_status =? OR order_items.removed_qty > 0 OR order_items.added_count > 0', 'partially_scanned', 'scanned').distinct

    if include_partially_scanned_orders == true
      if order_export_type == 'partially_scanned_only'
        orders = partially_orders
      elsif order_export_type == 'removed_only'
        partical_orders = partially_orders.joins(:order_items).where('order_items.removed_qty > 0 OR order_items.added_count > 0').distinct
        scan_orders = scanned_orders.joins(:order_items).where('order_items.removed_qty > 0 OR order_items.added_count > 0').distinct
        orders = partical_orders + scan_orders
      else
        orders = partially_orders + scanned_orders
      end
    else
      orders = if order_export_type == 'partially_scanned_only'
                 partially_orders
               elsif order_export_type == 'removed_only'
                 scanned_orders.joins(:order_items).where('order_items.removed_qty > 0 OR order_items.added_count > 0').distinct
               else
                 scanned_orders
               end
    end

    ExportSetting.update_all(last_exported: Time.current)
    filename = generate_file_name
    if order_export_type == 'do_not_include'
      do_export_if_orders_not_included(orders, filename)
    else
      do_export_with_orders(orders, filename, tenant)
    end
    filename
    # end
  end

  private

  def auto_email_export_with_changed_hash
    auto_email_export &&
      saved_change_to_time_to_send_export_email.present? &&
      order_export_email.present?
  end

  def auto_stat_email_export_with_changed_hash
    auto_stat_email_export && saved_change_to_time_to_send_stat_export_email.present? && stat_export_email.present?
  end

  def auto_email_daily_export_with_changed_hash
    daily_packed_email_export && saved_change_to_time_to_send_daily_packed_export_email.present? && daily_packed_email.present?
  end

  def schedule_job(type, time)
    job_scheduled = false
    date = DateTime.now.in_time_zone
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
    Delayed::Job.where('queue =? && run_at < ?', "order_export_email_scheduled_#{tenant}", Time.current).destroy_all
    # Delayed::Job.where(
    #   queue: "order_export_email_scheduled_#{tenant}"
    # ).destroy_all
  end

  def destroy_daily_packed_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where('queue =? && run_at < ?', "generate_daily_packed_export_#{tenant}", Time.current).destroy_all
  end

  def destroy_stat_export_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where('queue =? && run_at < ?', "generate_stat_export_#{tenant}", Time.current).destroy_all
  end

  def update_single_row(single_row, order, box = nil, order_item = nil)
    single_row[:order_number] = order.increment_id
    single_row[:order_status] = order.status
    single_row[:order_date] = order.order_placed_time
    single_row[:store_name] = order&.store&.display_origin_store_name ? order.origin_store&.store_name : order.store&.name
    single_row[:scanned_date] = order.scanned_on&.strftime('%Y-%m-%d %I:%M:%S %p')
    single_row[:address1] = order.address_1
    single_row[:address2] = order.address_2
    single_row[:city] = order.city
    single_row[:state] = order.state
    single_row[:zip] = order.postcode
    single_row[:customer_name] = order.customer_name
    single_row[:tracking_num] = order.tracking_num
    single_row[:incorrect_scans] = order.inaccurate_scan_count
    single_row[:clicked_scanned_qty] = order_item.clicked_qty
    single_row[:added_count] = order_item.added_count
    single_row[:custom_order_1] = GeneralSetting.first.custom_field_one
    single_row[:custom_order_2] = GeneralSetting.first.custom_field_two
    if box.present?
      single_row[:ordered_qty] = box.order_item_boxes.where(order_item_id: order_item.id).last.item_qty
      single_row[:box_number] = box.name.split(' ').last
    end
  end

  def update_single_row_for_packing_user(single_row, order_item, order)
    packing_user = order.packing_user
    return if packing_user.blank?

    single_row[:packing_user] = "#{packing_user.name} (#{packing_user.username})"
    single_row[:warehouse_name] = order_item.product.try(:primary_warehouse)
                                            .try(:inventory_warehouse).try(:name)
  end

  def update_single_row_for_product_info(single_row, order_item, order_item_kit = nil)
    product = order_item.product
    if product&.is_kit == 1 && order_item_kit.present?
      return update_partially_scanned_kit(single_row, order_item, product, order_item_kit)
    end
    single_row[:product_name] = product&.name
    single_row[:barcode] = product&.primary_barcode
    single_row[:primary_sku] = product&.primary_sku
    single_row[:item_sale_price] = order_item.price
    single_row[:scanned_count] = order_item.scanned_qty
    single_row[:unscanned_count] = order_item.qty - order_item.scanned_qty
    single_row[:removed_count] = order_item.removed_qty
    single_row[:scanning_user] = order_item.order.packing_user&.username || order_item.order&.order_activities&.last&.username
  end

  def update_partially_scanned_kit(single_row, order_item, product, kit_product)
    kit_product_sku = ProductKitSkus.find_by(id: kit_product&.product_kit_skus_id)
    product_barcode = ProductBarcode.find_by(product_id: kit_product_sku&.option_product_id)
    product_sku = ProductSku.find_by(product_id: kit_product_sku&.option_product_id)
    kit_product_name = Product.find_by(id: kit_product_sku&.option_product_id)

    single_row[:product_name] = product&.name
    single_row[:kit_name] = kit_product_name&.name
    single_row[:primary_sku] = product_sku&.sku
    single_row[:barcode] = product_barcode&.barcode
    single_row[:scanned_count] = kit_product&.scanned_qty
    single_row[:item_sale_price] = order_item&.price
    single_row[:ordered_qty] = kit_product&.order_item.qty * kit_product_sku&.qty
    single_row[:unscanned_count] = kit_product&.order_item.qty - kit_product&.scanned_qty
    single_row[:clicked_scanned_qty] = kit_product&.clicked_qty
    single_row[:removed_count] = order_item&.removed_qty
    single_row[:scanning_user] = order_item&.order.packing_user&.username || order_item&.order&.order_activities&.last&.username
  end

  def set_start_and_end_time
    start_time = begin
                   self.start_time.beginning_of_day
                 rescue StandardError
                   (DateTime.now.in_time_zone - 1.days)
                 end
    end_time = begin
                 self.end_time.end_of_day
               rescue StandardError
                 DateTime.now.in_time_zone
               end
    return [start_time, end_time] if manual_export

    if export_orders_option.eql? 'on_same_day'
      begin
        job_time = Delayed::Job.where(queue: "order_export_email_scheduled_#{Apartment::Tenant.current}").map(&:locked_at).compact[0]
        job_time = DateTime.now.in_time_zone if job_time.blank?
        start_time = job_time - time_to_send_export_email.strftime('%H').to_i.hours - time_to_send_export_email.strftime('%M').to_i.minutes
        end_time = job_time
      rescue StandardError
        # If time_to_send_export_email is not present
        time_to_send_export_email ||= 12.hour.from_now
        time = time_to_send_export_email.strftime('%H:%M')
        seconds = Time.zone.parse(time).seconds_since_midnight
        start_time = Time.current
        end_time = Time.current.beginning_of_day + seconds
      end
    else
      start_time = last_exported || '2000-01-01 00:00:00'
      end_time = Time.current
    end
    # end_time = Time.current.utc.beginning_of_day + seconds - GeneralSetting.last.time_zone.to_i
    # start_time = same_day_or_last_exported(start_time)
    [start_time, end_time]
  end

  # def same_day_or_last_exported(start_time)
  #   if export_orders_option.eql? 'on_same_day'
  #     Time.current.beginning_of_day
  #   else
  #     last_exported || '2000-01-01 00:00:00'
  #   end
  # end

  def with_error_filename
    # result['status'] = false
    # result['messages'].push('We need a start and an end time')
    CSV.generate do |csv|
      csv << result['messages']
    end
    'error.csv'
  end

  def generate_file_name
    "groove-order-export-#{Time.current.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
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
        csv << single_row.values
      end
    end
    tenant = Apartment::Tenant.current
    GroovS3.create_export_csv(tenant, filename, data)
    # url = GroovS3.find_export_csv(tenant, filename)
    # ExportOrder.export(tenant).deliver if ExportSetting.first.manual_export == true
  end

  def generate_row_mapping
    {
      order_date: '',
      order_status: '',
      order_number: '',
      store_name: '',
      scanned_qty: '',
      packing_user: '',
      scanned_date: '',
      click_scanned_qty: '',
      tracking_num: '',
      incorrect_scans: '',
      clicked_scanned_qty: '',
      box_number: '',
      scanned_count: '',
      unscanned_count: '',
      removed_count: '',
      scanning_user: ''
    }
  end

  def update_single_row_with_order_data(row_map, order)
    single_row = row_map.dup
    single_row[:order_number] = order.increment_id
    single_row[:order_status] = order.status
    single_row[:scanned_qty] = order.scanned_items_count
    single_row[:store_name] = order&.store&.display_origin_store_name ? order.origin_store&.store_name : order.store&.name
    single_row[:order_date] = order.order_placed_time
    single_row[:scanned_date] = order.scanned_on&.strftime('%Y-%m-%d %I:%M:%S %p')
    single_row[:tracking_num] = order.tracking_num
    single_row[:incorrect_scans] = order.inaccurate_scan_count
    single_row[:clicked_scanned_qty] = order.clicked_scanned_qty.to_i
    single_row[:click_scanned_qty] = calculate_clicked_qty(order)
    single_row[:scanned_count] = order.order_items.sum(:scanned_qty)
    single_row[:unscanned_count] = order.order_items.sum(:qty) - order.order_items.sum(:scanned_qty)
    single_row[:removed_count] = order.order_items.sum(:removed_qty)
    single_row[:scanning_user] = order.packing_user&.username 
    single_row
  end

  def assign_packing_user(single_row, order)
    packing_user = order.packing_user
    return unless packing_user

    single_row[:packing_user] = "#{packing_user.name} ( #{packing_user.username} )"
  end

  def calculate_clicked_qty(order)
    order.order_items.map(&:clicked_qty).sum
  end
end
