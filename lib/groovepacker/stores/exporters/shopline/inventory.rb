# frozen_string_literal: true

module Groovepacker
  module Stores
    module Exporters
      module Shopline
        class Inventory < Groovepacker::Stores::Importers::Importer
          attr_accessor :tenant, :store_id
          attr_reader :shopline_credential

          include ProductsHelper
          def initialize(tenant, store_id)
            @tenant = tenant
            @store_id = store_id
          end

          def push_inventories
            init_credential_and_client

            products = Product.joins(:sync_option).includes(:product_inventory_warehousess, :sync_option).where('sync_with_shopline=true and (shopline_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')

            products.in_batches(of: 250) do |products_batch|
              products_batch.each do |product|
                sync_optn = product.sync_option

                next if sync_optn.shopline_product_variant_id.blank?

                inventory_item_id = inventory_item_id(sync_optn)

                next if inventory_item_id.blank?

                inventory_data_to_be_updated = {
                  available_adjustment: delta(inventory_item_id, product),
                  inventory_item_id: inventory_item_id,
                  location_id: shopline_product_inv_push_location.try(:[], 'id')
                }

                sync_inventory_with_shopline(inventory_data_to_be_updated)
              rescue StandardError => e
                puts e
                next
              end

            end

            send_push_inventories_products_email
          end

          private

          def init_credential_and_client
            Apartment::Tenant.switch! tenant
            @shopline_credential = ShoplineCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShoplineRuby::Client.new(shopline_credential)
          end

          def shopline_product_inv_push_location
            @shopline_product_inv_push_location ||= shopline_credential.push_inv_location&.last&.first
          end

          def shopline_inventory_items(shopline_inventory_item_id)
            @client.inventory_levels(shopline_inventory_item_id, shopline_product_inv_push_location.try(:[], 'id'))['inventory_levels']&.first || {}
          end

          def sync_inventory_with_shopline(inventory_data_to_be_updated)
            response = @client.adjust_inventory(inventory_data_to_be_updated)
            puts response.inspect
          end

          # need to handle shopline
          def inventory_item_id(sync_option)
            return sync_option.shopline_inventory_item_id if sync_option.shopline_inventory_item_id

            shopline_product_inv = @client.get_variant(sync_option.shop_product_variant_id)
            sync_option.update(shopline_inventory_item_id: shopline_product_inv['inventory_item_id'])
            sync_option.shopline_inventory_item_id
          end

          def delta(inventory_item_id, product)
            inv_wh = product.product_inventory_warehousess.last
            current_gp_inv = inv_wh&.available_inv.to_i
            shopline_inventory_item = shopline_inventory_items(product.sync_option.shopline_inventory_item_id)
            create_inventory(inventory_item_id) if shopline_inventory_item.blank?
            current_gp_inv - shopline_inventory_item['available'].to_i
          end

          def create_inventory(inventory_item_id)
            @client.update_inventory(
              available: 0,
              location_id: shopline_product_inv_push_location['id'],
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
