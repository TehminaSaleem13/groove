# frozen_string_literal: true

module Groovepacker
  module Stores
    module Exporters
      module Shopify
        class Inventory < Groovepacker::Stores::Importers::Importer
          attr_accessor :tenant, :store_id
          attr_reader :shopify_credential

          include ProductsHelper
          def initialize(tenant, store_id)
            @tenant = tenant
            @store_id = store_id
          end

          def push_inventories
            init_credential_and_client

            products = Product.joins(:sync_option).where('sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')

            products.each do |product|
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

              # sleep 0.5

              update_inv_on_shopify_for_sync_option(product, attrs)
            rescue Exception => e
              puts e
              next
            end
            send_push_inventories_products_email
          end

          private

          def init_credential_and_client
            Apartment::Tenant.switch! tenant
            @shopify_credential = ShopifyCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)
          end

          def shopify_product_location
            return @shopify_product_location if @shopify_product_location

            shopify_credential.push_inv_location
          end

          def update_inv_on_shopify_for_sync_option(_product, attrs)
            @client.update_inventory(attrs)
          end

          def send_push_inventories_products_email
            CsvExportMailer.send_push_pull_inventories_products(tenant, 'push_inv').deliver
          end
        end
      end
    end
  end
end
