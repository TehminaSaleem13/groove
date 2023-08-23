# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Shopify
        class Inventory < Groovepacker::Stores::Importers::Importer
          attr_accessor :tenant, :store_id
          attr_reader :shopify_credential

          include ProductsHelper

          def initialize(tenant, store_id)
            @tenant = tenant
            @store_id = store_id
          end

          def pull_inventories
            init_credential_and_client

            # products = Product.where(store_id: credential.store_id)
            products = Product.joins(:sync_option).where('sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')

            (products || []).each do |product|
              inv_wh = product.product_inventory_warehousess.first
              @sync_optn = product.sync_option
              shopify_product_variant_id = @sync_optn.shopify_product_variant_id
              next if shopify_product_variant_id.blank?

              shopify_product_inv = get_inventory(shopify_product_variant_id)

              sleep 0.5

              update_product_inv_for_sync_option(product, shopify_product_inv, inv_wh) unless shopify_product_inv.blank?
            rescue Exception => e
              puts e
              next
            end
            send_pull_inventories_products_email
          end

          private

          def init_credential_and_client
            Apartment::Tenant.switch! tenant
            @shopify_credential = ShopifyCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)
          end

          def update_product_inv_for_sync_option(_product, shopify_product_inv, inv_wh)
            return unless @sync_optn.shopify_product_variant_id == shopify_product_inv['id']&.to_s

            inv_wh.quantity_on_hand = inv_wh.allocated_inv.to_i + shopify_product_inv['inventory_quantity'].to_i
            inv_wh.save!
          end

          def send_pull_inventories_products_email
            CsvExportMailer.send_push_pull_inventories_products(tenant, 'pull_inv').deliver
          end

          def get_inventory(shopify_product_variant_id)
            variant = @client.get_variant(shopify_product_variant_id)

            return variant if shopify_credential.pull_combined_qoh

            inventory_level = inventory_levels.find { |inv_level| inv_level['inventory_item_id'] == variant['inventory_item_id'] }

            variant['inventory_quantity'] = inventory_level.try(:[], 'available')
            variant
          end

          def inventory_levels
            @inventory_levels ||= @client.inventory_levels(shopify_credential.pull_inv_location_id)
          end
        end
      end
    end
  end
end
