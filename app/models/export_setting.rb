class ExportSetting < ActiveRecord::Base
  include ExportData

  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
                  :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
                  :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun,
                  :last_exported, :export_orders_option, :order_export_type, :order_export_email,
                  :start_time, :end_time, :manual_export

  after_save :scheduled_export

  def scheduled_export
    if auto_email_export_with_changed_hash
      schedule_job
    else
      destroy_order_export_email_scheduled
    end
  end

  def should_export_orders_today
    day = DateTime.now.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def should_export_orders(date)
    day = date.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def calculate_row_data(single_row, order_item)
    order = order_item.order
    update_single_row(single_row, order)
    update_single_row_for_packing_user(order_item, order)
    single_row[:barcode] = order_item.product.primary_barcode
    if order_item.product.is_kit == 1
      single_row[:kit_name] = order_item.product.name
    else
      single_row[:product_name] = order_item.product.name
    end
    single_row[:primary_sku] = order_item.product.primary_sku
    single_row[:item_sale_price] = order_item.price
    single_row
  end

  private

  def auto_email_export_with_changed_hash
    auto_email_export &&
      changes[:time_to_send_export_email].present? &&
      order_export_email.present?
  end

  def schedule_job
    job_scheduled = false
    date = DateTime.now
    general_settings = GeneralSetting.all.first
    7.times do
      job_scheduled = general_settings.schedule_job(
        date, time_to_send_export_email, 'export_order'
      )
      date += 1.day
      break if job_scheduled
    end
  end

  def destroy_order_export_email_scheduled
    tenant = Apartment::Tenant.current
    Delayed::Job.where(
      queue: "order_export_email_scheduled_#{tenant}"
    ).destroy_all
  end

  def update_single_row(order)
    single_row[:order_number] = order.increment_id
    single_row[:order_date] = order.order_placed_time
    single_row[:scanned_date] = order.scanned_on
    single_row[:address1] = order.address_1
    single_row[:address2] = order.address_2
    single_row[:city] = order.city
    single_row[:state] = order.state
    single_row[:zip] = order.postcode
    single_row[:customer_name] = order.customer_name
  end

  def update_single_row_for_packing_user(order_item, order)
    packing_user = User.where(id: order.packing_user_id).first
    return if packing_user.blank?
    single_row[:packing_user] = "#{packing_user.name} (#{packing_user.username})"
    single_row[:warehouse_name] = order_item.product.primary_warehouse
                                  .try(:inventory_warehouse).try(:name)
  end
end
