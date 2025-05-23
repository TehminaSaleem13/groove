# frozen_string_literal: true

namespace :doo do
  desc 'import shopify orders from each active store at every 10 mins'
  task import_shopify_orders: :environment do
    next if $redis.get('import_shopify_orders_every_10_minutes')

    $redis.set('import_shopify_orders_every_10_minutes', true)
    $redis.expire('import_shopify_orders_every_10_minutes', 180)

    Tenant.order(:name).find_each.each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      next if OrderImportSummary.where(status: 'in_progress').present?

      stores = Store.shopify_active_stores.includes(:shopify_credential)
      stores.each do |store|
        credential = store&.shopify_credential
        next unless credential&.webhook_order_import

        ImportOrders.new.delay(priority: 95, queue: "import_shopify_orders_#{tenant.name}_#{store.name}").import_shopify_orders(
          tenant.name, store.id
        )
      end
    end
  end
end
