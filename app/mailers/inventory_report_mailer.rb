# frozen_string_literal: true

class InventoryReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def manual_inventory_report(id, tenant)
    Apartment::Tenant.switch! tenant
    @product_inv_setting = InventoryReportsSetting.last
    selected_reports = ProductInventoryReport.where(id: id)
    return if selected_reports.blank?

    selected_reports.each do |report|
      products = get_products(report)
      if report.type
        flag = true
        file_name = "sku_per_day_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
        data = InventoryReport::SkuPerDay.new(@product_inv_setting, products, flag).get_data
      else
        file_name = "inventory_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
        data = InventoryReport::InvProjection.new(@product_inv_setting, products).get_data
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
    reports = if report_ids.present?
                ProductInventoryReport.where(id: report_ids)
              else
                report.present? ? [report] : ProductInventoryReport.where(scheduled: true)
              end
    @product_inv_setting = InventoryReportsSetting.last
    reports.each do |report|
      products = get_products(report)
      if report.type
        file_name = "sku_per_day_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
        data = InventoryReport::SkuPerDay.new(@product_inv_setting, products, flag).get_data
      else
        file_name = "inventory_report_#{Time.current.strftime('%y%m%d_%H%M%S')}.csv"
        data = InventoryReport::InvProjection.new(@product_inv_setting, products).get_data
      end
      attachments[file_name] = { mime_type: 'text/csv', content: data }
    end
    subject = "Inventory Projection Report [ #{tenant || Apartment::Tenant.current} ]"
    email = @product_inv_setting.report_email
    # mail to: email, subject: subject
    mail(to: email, subject: subject)
  end

  def get_products(report)
    if (report.name == 'All_Products_Report') && report.is_locked
      Product.includes(:product_inventory_warehousess)
    elsif (report.name == 'Active_Products_Report') && report.is_locked
      Product.includes(:product_inventory_warehousess).where(status: 'active')
    else
      report.products.includes(:product_inventory_warehousess)
    end
  end
end
