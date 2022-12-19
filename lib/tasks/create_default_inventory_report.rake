# frozen_string_literal: true

namespace :doo do
  desc 'Create Default Report'
  task create_default_inventory_report: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      Apartment::Tenant.switch! tenant.name
      ProductInventoryReport.create(name: 'All_Products_Report', is_locked: true)
      ProductInventoryReport.create(name: 'Active_Products_Report', is_locked: true)
    rescue StandardError
    end
    exit(1)
  end
end
