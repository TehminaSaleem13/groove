# frozen_string_literal: true

class InventoryReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def manual_inventory_report(id, tenant)
    Apartment::Tenant.switch! tenant
    @product_inv_setting = InventoryReportsSetting.last

    @product_inv_setting.start_time ||= 7.days.ago
    @product_inv_setting.end_time ||= Time.current
    selected_reports = ProductInventoryReport.where(id: id, type: [false, nil])
    return if selected_reports.blank?

    start_time = @product_inv_setting&.start_time&.strftime('%m-%d-%Y')
    end_time = @product_inv_setting&.end_time&.strftime('%m-%d-%Y')

    days = (@product_inv_setting&.end_time&.end_of_day - @product_inv_setting&.start_time&.beginning_of_day).to_i rescue 7

    headers = ['DATE RANGE', 'SKU', 'PRODUCT NAME', 'SELECTED RANGE QTY SCANNED', 'PAST 14D QTY SCANNED', 'PAST 30D QTY SCANNED', 'PAST 60D QTY SCANNED', 'PAST 90D QTY SCANNED', 'PROJ DAYS REMAINING BASED ON SELECTED RANGE', 'PROJ DAYS REMAINING BASED ON 14D', 'PROJ DAYS REMAINING BASED ON 30D', 'PROJ DAYS REMAINING BASED ON 60D', 'PROJ DAYS REMAINING BASED ON 90D', 'CURRENT AVAILABLE', 'CURRENT QOH', 'CATEGORY', 'LOCATION1', 'LOCATION2', 'LOCATION3', 'RESTOCK LEAD TIME']

    selected_reports.each do |report|
      products = get_products(report)
      file_name = "inventory_report_#{Time.now.strftime('%y%m%d_%H%M%S')}.csv"
      data = CSV.generate(headers: true) do |csv|
        csv << headers
        products.each do |pro|

          pro_orders = pro.order_items.map(&:order)
          inv = pro.product_inventory_warehousess
          restock_lead_time = pro.restock_lead_time || 0

          orders = Order.where('id IN (?) and scanned_on >= ? and scanned_on <= ?', pro_orders.map(&:id), @product_inv_setting.try(:start_time).try(:beginning_of_day), @product_inv_setting.try(:end_time).try(:end_of_day))
          orders_14 = Order.where('id IN (?) and scanned_on >= ?', pro_orders.map(&:id), Time.now - 14.days) rescue []
          orders_30 = Order.where('id IN (?) and scanned_on >= ?', pro_orders.map(&:id), Time.now - 30.days) rescue []
          orders_60 = Order.where('id IN (?) and scanned_on >= ?', pro_orders.map(&:id), Time.now - 60.days) rescue []
          orders_90 = Order.where('id IN (?) and scanned_on >= ?', pro_orders.map(&:id), Time.now - 90.days) rescue []

          available_inv = inv.map(&:available_inv).sum
          quantity_on_hand = inv.map(&:quantity_on_hand).sum

          projected_days_remaining = ((quantity_on_hand.to_f / (orders.count.to_f / days)) - restock_lead_time) rescue 0
          projected_days_remaining_14 = ((quantity_on_hand.to_f / (orders_14.count.to_f / 14)) - restock_lead_time) rescue 0
          projected_days_remaining_30 = ((quantity_on_hand.to_f / (orders_30.count.to_f / 30)) - restock_lead_time) rescue 0
          projected_days_remaining_60 = ((quantity_on_hand.to_f / (orders_60.count.to_f / 60)) - restock_lead_time) rescue 0
          projected_days_remaining_90 = ((quantity_on_hand.to_f / (orders_90.count.to_f / 90)) - restock_lead_time) rescue 0

          csv << ["#{start_time} to #{end_time}", pro.primary_sku.to_s, pro.name.tr(',', ' ').to_s, orders&.count.to_s, orders_14&.count.to_s, orders_30&.count.to_s, orders_60&.count.to_s, orders_90&.count.to_s, projected_days_remaining.round(1), projected_days_remaining_14.round(1), projected_days_remaining_30.round(1), projected_days_remaining_60.round(1), projected_days_remaining_90.round(1), available_inv, quantity_on_hand, pro.product_cats[0].try(:category), inv[0].try(:location_primary), inv[0].try(:location_secondary), inv[0].try(:location_tertiary), pro.restock_lead_time]
        end
      end
      attachments[file_name] = { mime_type: 'text/csv', content: data }
    end
    subject = 'Inventory Projection Report [' + tenant + ']'
    email = @product_inv_setting.report_email
    # mail to: email, subject: subject
    mail(to: email, subject: subject)
  end

  def auto_inventory_report(flag, report = nil, report_ids = nil, tenant)
    Apartment::Tenant.switch! tenant if tenant.present?
    if report_ids.present?
      reports = ProductInventoryReport.where(id: report_ids)
    else
      reports = report.present? ? [report] : ProductInventoryReport.where(scheduled: true)
    end
    @product_inv_setting = InventoryReportsSetting.last
    headers = %w[DATE_FOR_DAILY_TOTAL SKU PRODUCT_NAME DAILY_SKU_QTY]
    reports.each do |report|
      file_name = "sku_per_day_report_#{Time.now.strftime('%y%m%d_%H%M%S')}.csv"
      products = get_products(report)
      data = CSV.generate(headers: true) do |csv|
        csv << headers
        days = get_days(flag)
        days.times do |i|
          products.each do |pro|
            orders = pro.order_items.map(&:order)
            orders = [] if orders.blank?
            if flag == true
              orders = begin
                          Order.where('id IN (?) and scanned_on >= ? and scanned_on <= ?', orders.map(&:id), (@product_inv_setting.start_time + i.to_s.to_i.days).beginning_of_day, (@product_inv_setting.start_time + i.to_s.to_i.days).end_of_day)
                        rescue
                          []
                        end
              date = (@product_inv_setting.start_time + i.to_s.to_i.days).strftime('%m/%d/%y')
            else
              orders = begin
                          Order.where('id IN (?) and scanned_on >= ? and scanned_on <= ?', orders.map(&:id), (DateTime.now - i.to_s.to_i.days).beginning_of_day, (DateTime.now - i.to_s.to_i.days).end_of_day)
                        rescue
                          []
                        end
              date = (DateTime.now.beginning_of_day - i.to_s.to_i.days).strftime('%m/%d/%y')
            end
            csv << [date, pro.primary_sku, pro.name.tr(',', ' '), orders.count]
          end
        end
      end
      attachments[file_name] = { mime_type: 'text/csv', content: data }
      # attachments[file_name] = File.read("public/#{file_name}")
    end
    subject = 'Sku Per Day Report [' + tenant || Apartment::Tenant.current + ']'
    email = @product_inv_setting.report_email
    # mail to: email, subject: subject
    mail(to: email, subject: subject)
  end

  def get_days(flag)
    if flag == true
      @product_inv_setting.start_time ||= 7.days.ago
      @product_inv_setting.end_time ||= Time.current
      days = (@product_inv_setting.end_time.to_date - @product_inv_setting.start_time.to_date).to_i
      days = 0 if days < 0
    else
      days = @product_inv_setting.report_days_option
     end
    days
  end

  def get_products(report)
    if (report.name == 'All_Products_Report') && report.is_locked
      products = Product.all
    elsif (report.name == 'Active_Products_Report') && report.is_locked
      products = Product.where(status: 'active')
    else
      products = report.products
     end
    products
  end
end
