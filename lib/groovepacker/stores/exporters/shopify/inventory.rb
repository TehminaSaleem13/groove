# frozen_string_literal: true

module Groovepacker
  module Stores
    module Exporters
      module Shopify
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            Apartment::Tenant.switch! handler[:current_tenant] if handler[:store_handle]
            @credential = handler[:credential]
            @client = handler[:store_handle]

            products = Product.joins(:sync_option).where('sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')

            products.each do |product|
              begin
                inv_wh = product.product_inventory_warehousess.last
                inv_level = inv_wh&.available_inv.to_i

                @sync_optn = product.sync_option
                next if @sync_optn.shopify_product_variant_id.blank?

                shopify_product_inv = @client.get_variant(@sync_optn.shopify_product_variant_id)
                next if shopify_product_inv.blank?

                attrs = {
                  available: inv_level,
                  location_id: shopify_product_location['id'],
                  inventory_item_id: shopify_product_inv['inventory_item_id']
                }

                update_inv_on_shopify_for_sync_option(product, attrs)
              rescue Exception => e
                puts e
                next
              end
            end
          end

          private

          def shopify_product_location
            @shopify_product_location ||= @client.locations.first
          end

          def update_inv_on_shopify_for_sync_option(_product, attrs)
            @client.update_inventory(attrs)
          end
        end
      end
    end
  end
end
