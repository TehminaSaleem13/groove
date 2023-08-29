# frozen_string_literal: true

namespace :shopify do
  desc 'Add shopify_inventory_item_id to Sync Options'
  task update_shopify_inventory_item_id: :environment do
    tenants = Tenant.pluck(:name)

    tenants.each do |tenant|
      Apartment::Tenant.switch! tenant

      SyncOption.includes(product: { store: :shopify_credential }).where.not(shopify_product_variant_id: nil).where(shopify_inventory_item_id: nil).each do |sync_option|
        product = sync_option.product
        next unless product

        shopify_credential = product.store&.shopify_credential
        next unless shopify_credential

        client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)

        variant = client.get_variant(sync_option.shopify_product_variant_id)
        sync_option.update(shopify_inventory_item_id: variant['inventory_item_id']) if variant.present?
      end
    end
  end
end
