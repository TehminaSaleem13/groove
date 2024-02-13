# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      class ShopInventoryImporter < Groovepacker::Stores::Importers::Importer
        attr_accessor :tenant, :store_id
        attr_reader :shopify_credential, :shopline_credential

        include ProductsHelper

        def initialize(tenant, store_id)
          @tenant = tenant
          store = Store.find_by(id: store_id)
          @store_id = store_id
          @store_type = store.store_type
        end

        def pull_inventories
          init_credential_and_client

          # products = Product.where(store_id: credential.store_id)
          if @store_type == 'Shopline'
            products = Product.joins(:sync_option).where('sync_with_shopline=true and (shopline_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')
          else
            products = Product.joins(:sync_option).where('sync_with_shopify=true and (shopify_product_variant_id IS NOT NULL or store_product_id IS NOT NULL)')
          end

          (products || []).each do |product|
            inv_wh = product.product_inventory_warehousess.first
            @sync_option = product.sync_option
            shop_product_variant_id = @store_type == 'Shopline' ? @sync_option.shopline_product_variant_id : @sync_option.shopify_product_variant_id
            next if shop_product_variant_id.blank?

            shop_product_inv = get_inventory(shop_product_variant_id)

            sleep 0.5

            update_product_inv_for_sync_option(product, shop_product_inv, inv_wh) unless shop_product_inv.blank?
          rescue Exception => e
            puts e
            next
          end

          send_pull_inventories_products_email
        end

        private

        def init_credential_and_client
          Apartment::Tenant.switch! tenant
          if @store_type == 'Shopline'
            @shopline_credential = ShoplineCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShoplineRuby::Client.new(shopline_credential)
          else
            @shopify_credential = ShopifyCredential.find_by(store_id: store_id)
            @client = Groovepacker::ShopifyRuby::Client.new(shopify_credential)
          end
        end

        def update_product_inv_for_sync_option(_product, shop_product_inv, inv_wh)
          return if (@store_type == 'Shopify' && @sync_option.shopify_product_variant_id != shop_product_inv['id']&.to_s) ||
            (@store_type == 'Shopline' && @sync_option.shopline_product_variant_id != shop_product_inv['id']&.to_s)

          inv_wh.quantity_on_hand = inv_wh.allocated_inv.to_i + shop_product_inv['inventory_quantity'].to_i
          inv_wh.save!
        end

        def send_pull_inventories_products_email
          CsvExportMailer.send_push_pull_inventories_products(tenant, 'pull_inv').deliver
        end

        def get_inventory(shop_product_variant_id)
          variant = @client.get_variant(shop_product_variant_id)

          shop_credential = @store_type == 'Shopline' ? shopline_credential : shopify_credential
          return variant if shop_credential.pull_combined_qoh

          if @store_type == 'Shopline'
            inventory_level = shopline_inventory_levels(variant['inventory_item_id']).find { |inv_level| inv_level['inventory_item_id'] == variant['inventory_item_id'] }
          else
            inventory_level = shopify_inventory_levels.find { |inv_level| inv_level['inventory_item_id'] == variant['inventory_item_id'] }
          end

          variant['inventory_quantity'] = inventory_level.try(:[], 'available')
          variant
        end

        def shopify_inventory_levels
          @inventory_levels ||= @client.inventory_levels(shopify_credential.pull_inv_location_id)
        end

        def shopline_inventory_levels(inventory_item_id)
          @client.inventory_levels(inventory_item_id, shopline_credential.pull_inv_location_id)['inventory_levels']
        end
      end
    end
  end
end
