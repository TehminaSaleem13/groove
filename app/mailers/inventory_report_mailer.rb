# frozen_string_literal: true

class InventoryReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def manual_inventory_report(id, tenant)
    Apartment::Tenant.switch! tenant
    @product_inv_setting = InventoryReportsSetting.last
    selected_reports = ProductInventoryReport.where(id: id, type: [false, nil])
    return if selected_reports.blank?

    selected_reports.each do |report|
      products = get_products(report)
      file_name = "inventory_report_#{Time.now.strftime('%y%m%d_%H%M%S')}.csv"
      data = InventoryReport::InvProjection.new(@product_inv_setting, products).get_data
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
