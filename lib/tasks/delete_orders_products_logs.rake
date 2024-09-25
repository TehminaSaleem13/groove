# frozen_string_literal: true

namespace :doo do
  desc 'Delete Orders & Products logs earlier than 90 days'

  task delete_orders_products_logs: :environment do
    next if $redis.get('delete_orders_products_logs_earlier_than_90_days')

    $redis.set('delete_orders_products_logs_earlier_than_90_days', true)
    $redis.expire('delete_orders_products_logs_earlier_than_90_days', 180)
    tenants = Tenant.all
    tenants.find_each do |tenant|
      Apartment::Tenant.switch! tenant.name
      EventLog.where('created_at < ?', 90.days.ago).delete_all
    end
  end
end