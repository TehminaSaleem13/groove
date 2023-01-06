# frozen_string_literal: true

namespace :doo do
  desc 'Delete Orders & Products logs earlier than 90 days'

  task delete_orders_products_logs: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      Apartment::Tenant.switch! tenant.name
      EventLog.where('created_at < ?', 90.days.ago).delete_all
    end
  end
end