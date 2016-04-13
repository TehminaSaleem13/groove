class ExportSetting < ActiveRecord::Base
  include ExportData
  
  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
                  :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
                  :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun,
                  :last_exported, :export_orders_option, :order_export_type, :order_export_email,
                  :start_time, :end_time, :manual_export

  after_save :scheduled_export

  def scheduled_export
    result = Hash.new
    changed_hash = self.changes
    if self.auto_email_export && !changed_hash[:time_to_send_export_email].nil? && !self.order_export_email.blank?
      job_scheduled = false
      date = DateTime.now
      general_settings = GeneralSetting.all.first
      for i in 0..6
        job_scheduled = general_settings.schedule_job(date,
                                                      self.time_to_send_export_email, 'export_order')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: "order_export_email_scheduled_#{tenant}").destroy_all
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
    single_row[:order_number] = order_item.order.increment_id
    single_row[:order_date] = order_item.order.order_placed_time
    single_row[:scanned_date] = order_item.order.scanned_on
    single_row[:address1] = order_item.order.address_1
    single_row[:address2] = order_item.order.address_2
    single_row[:city] = order_item.order.city
    single_row[:state] = order_item.order.state
    single_row[:zip] = order_item.order.postcode
    single_row[:customer_name] = [order_item.order.firstname, order_item.order.lastname].join(' ')
    packing_user = nil
    packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
    unless packing_user.nil?
      single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
      single_row[:warehouse_name] = order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
    end
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
end
