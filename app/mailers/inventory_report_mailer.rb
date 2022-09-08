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
      file_name = "inventory_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
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
    reports.each do |report|
      file_name = "sku_per_day_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
      products = get_products(report)
      data = InventoryReport::SkuPerDay.new(@product_inv_setting, products, flag).get_data
      attachments[file_name] = { mime_type: 'text/csv', content: data }
      # attachments[file_name] = File.read("public/#{file_name}")
    end
    subject = "Inventory Projection Report [ #{tenant || Apartment::Tenant.current} ]"
    email = @product_inv_setting.report_email
    # mail to: email, subject: subject
    mail(to: email, subject: subject)
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
