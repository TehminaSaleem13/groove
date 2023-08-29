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

            products = Product.joins(:sync_option).includes(:product_inventory_warehousess, :sync_option).where('sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')

            products.in_batches(of: 250) do |products_batch|
              inventory_data_to_be_updated = []

              products_batch.each do |product|
                sync_optn = product.sync_option
                next if sync_optn.shopify_product_variant_id.blank?

                inventory_item_id = inventory_item_id(sync_optn)
                next if inventory_item_id.blank?

                inventory_data_to_be_updated << {
                  delta: delta(inventory_item_id, product),
                  inventoryItemId: "gid://shopify/InventoryItem/#{inventory_item_id}",
                  locationId: "gid://shopify/Location/#{shopify_product_inv_push_location['id']}"
                }
              rescue StandardError => e
                puts e
                next
              end

              sync_inventory_with_shopify(inventory_data_to_be_updated)
            end

            send_push_inventories_products_email
          end

          private

          def init_credential_and_client
            Apartment::Tenant.switch! tenant
            @shopify_credential = ShopifyCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)
          end

          def shopify_product_inv_push_location
            @shopify_product_inv_push_location ||= shopify_credential.push_inv_location
          end

          def shopify_inventory_items
            @shopify_inventory_items ||= @client.inventory_levels(shopify_product_inv_push_location['id'])
          end

          def sync_inventory_with_shopify(inventory_data_to_be_updated)
            query = <<~QUERY
              mutation inventoryAdjustQuantities($input: InventoryAdjustQuantitiesInput!) {
                inventoryAdjustQuantities(input: $input) {
                  userErrors {
                    field
                    message
                  }
                  inventoryAdjustmentGroup {
                    createdAt
                    reason
                    changes {
                      name
                      delta
                    }
                  }
                }
              }
            QUERY

            variables = {
              input: {
                reason: 'correction',
                name: 'available',
                changes: inventory_data_to_be_updated.as_json
              }
            }

            response = @client.execute_grahpql_query(query: query, variables: variables)
            puts response.inspect
          end

          def inventory_item_id(sync_option)
            return sync_option.shopify_inventory_item_id if sync_option.shopify_inventory_item_id

            shopify_product_inv = @client.get_variant(sync_option.shopify_product_variant_id)
            sync_option.update(shopify_inventory_item_id: shopify_product_inv['inventory_item_id'])
            sync_option.shopify_inventory_item_id
          end

          def delta(inventory_item_id, product)
            inv_wh = product.product_inventory_warehousess.last
            current_gp_inv = inv_wh&.available_inv.to_i
            shopify_inventory_item = shopify_inventory_items.find { |item| item['inventory_item_id'].to_s == inventory_item_id } || {}
            create_inventory(inventory_item_id) if shopify_inventory_item.blank?
            current_gp_inv - shopify_inventory_item['available'].to_i
          end

          def create_inventory(inventory_item_id)
            @client.update_inventory(
              available: 0,
              location_id: shopify_product_inv_push_location['id'],
              inventory_item_id: inventory_item_id
            )
          end

          def send_push_inventories_products_email
            CsvExportMailer.send_push_pull_inventories_products(tenant, 'push_inv').deliver
          end
        end
      end
    end
  end
end
