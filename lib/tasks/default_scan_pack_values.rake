# frozen_string_literal: true

namespace :update_settings do
  desc 'Set default scanpack setting attributes'
  task default_scan_pack_values: :environment do
    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        Apartment::Tenant.switch! tenant
        scan_pack_setting = ScanPackSetting.first
        next unless scan_pack_setting

        scan_pack_setting.email_subject = 'YourCompany Order - [[ORDER-NUMBER]] - Packing Details'
        scan_pack_setting.email_message = '<h4 style="color: rgb(85, 85, 85);background-color: rgb(255, 255, 255);"><span>This email was sent on behalf of </span><b><b><b><i>http://YourCompany.com </i></b></b></b><span>to let you know your order number [[ORDER-NUMBER]] has been scanned by the fulfillment team. You can review an image of your order items and a scanning log here: [[CUSTOMER-PAGE-URL]]</span><br/></h4>'
        scan_pack_setting.customer_page_message = '<h4>To ensure the accuracy of your order <i>YourCompany</i> scans every item as your package is packed. The image below was taken immediately after the items were scanned. The scanning log shows each scan.</h4><h4>If you see any issues, or if you need assistance, please contact support regarding your order here: <b><i>http://YourCompany.com/Support</i></b><br/></h4>'
        scan_pack_setting.save
      rescue StandardError
        next
      end
    end
  end
end
