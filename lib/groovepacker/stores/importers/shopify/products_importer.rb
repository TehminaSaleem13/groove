# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Shopify
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include ProductMethodsHelper

          def import(product_import_type, product_import_range_days)
            initialize_import_objects
            begin
              response = @client.products(product_import_type, product_import_range_days)
            rescue StandardError
              @store_product_import.try(:destroy)
              Product.emit_message_for_access_token
            end
            if response['products'].nil?
              @store_product_import.try(:destroy)
              Product.emit_message_for_access_token
              return
            end
            @store_product_import.try(:destroy) && return if response['products'].blank?
            products_response = response['products'].compact.sort_by { |products| Time.zone.parse(products['updated_at']) }
            begin
              @store_product_import.update(status: 'in_progress', total: products_response.count)
            rescue StandardError
              nil
            end
            products_response.each do |product|
              return unless begin
                               @store_product_import.reload.present?
                            rescue StandardError
                              false
                             end

              create_single_product(product)
              begin
                @store_product_import.update(success_imported: @store_product_import.success_imported + 1)
              rescue StandardError
                nil
              end
              @credential.update(product_last_import: Time.zone.parse(product['updated_at'])) # if products_response.last == product
            end
            @store_product_import.try(:destroy)
            update_orders_status
            send_products_import_complete_email(response['products'].count)
          end

          def import_single_product(item)
            initialize_import_objects
            fetch_product(item)
            if @shopify_product.present?
              if !custom_shopify_item?(item)
                variant = @shopify_product['variants'].select { |variant| variant['id'] == item['variant_id'] }.first

                # If variant not found by id find by sku
                variant = @shopify_product['variants'].select { |variant| variant['sku'] == item['sku'] }.first if variant.blank? && item['sku'].present?

                if variant.blank?
                  on_demand_logger = Logger.new("#{Rails.root}/log/shopify_missing_product_variant_import_#{Apartment::Tenant.current}.log")
                  log = { item: item, Time: Time.zone.now, shopify_product: @shopify_product }
                  on_demand_logger.info(log)
                end
              elsif custom_shopify_item?(item)
                variant = item
                assign_attr_to_variant_for_custom_item(variant, item)
              end
              begin
                variant_title = variant['title'] == 'Default Title' ? '' : @credential.import_variant_names ? variant['title'] : " - #{variant['title']}"
                variant['title'] = @credential.import_variant_names ? item['title'] : item['name']
                product = create_product_from_variant(variant, @shopify_product)
              rescue StandardError
                product = nil
              end
              product.update_columns(custom_product_1:variant_title, custom_product_display_1:true) if variant_title.present? && product
            end
            product
          end

          def fetch_product(item)
            shopify_product = @client.product(item['product_id'])
            if shopify_product['product'].blank?
              loop_count = 0
              loop do
                loop_count += 1
                shopify_product = @client.product(item['product_id'])
                break if loop_count >= 1
              end
            end

            if shopify_product['product'].blank?
              on_demand_logger = Logger.new("#{Rails.root}/log/shopify_product_import_#{Apartment::Tenant.current}.log")
              log = { item: item, Time: Time.zone.now, shopify_product: shopify_product }
              on_demand_logger.info(log)
            end

            return @shopify_product = item if custom_shopify_item?(item)

            @shopify_product = shopify_product['product']
          end

          private

          def initialize_import_objects
            handler = get_handler
            @credential = handler[:credential]
            @store = @credential.try(:store)
            @client = handler[:store_handle]
            @store_product_import = StoreProductImport.find_by_store_id(@store&.id)
          end

          def custom_shopify_item?(item)
            item['fulfillable_quantity']&.positive? && !item['gift_card'] && item['product_id'].nil? &&
              item['sku'].nil? && !item['product_exists'] && item['variant_id'].nil?
          end

          def create_single_product(shopify_product)
            shopify_product['variants'].each do |variant|
              variant_title = variant['title'] == 'Default Title' ? '' : @credential.import_variant_names ? variant['title'] : " - #{variant['title']}"
              variant['title'] = @credential.import_variant_names ? shopify_product['title'] : shopify_product['title'] + variant_title
              product = create_product_from_variant(variant, shopify_product)
              product.update_columns(custom_product_1:variant_title, custom_product_display_1:true) if variant_title.present? && @credential.import_variant_names
              product = begin
                            product.reload
                        rescue StandardError
                          product
                          end
              product.update_columns(store_product_id: variant['id']) if variant['id'].present?
              if @credential.import_inventory_qoh
                product.product_inventory_warehousess.first
                       .update_attributes(available_inv: variant['inventory_quantity'])
              end
              product.set_product_status
            end
          end

          def create_product_from_variant(variant, shopify_product)
            if variant['sku'].blank?
              product = create_product_with_temp_sku(variant, shopify_product)
            elsif @credential.import_updated_sku && ProductSku.where(sku: variant['sku']).empty? && !Product.where(store_product_id: variant['id']).empty?
              product = Product.where(store_product_id: variant['id']).first
              product.product_skus.destroy_all if @credential.updated_sku_handling == 'remove_all'
              product.product_skus.create(sku: variant['sku'])
              update_product_details_barcode(product, variant)
            elsif ProductSku.where(sku: variant['sku']).empty?
              # if non-nil sku is not found
              product = create_new_product_from_order(variant, variant['sku'], shopify_product)
            else
              product = ProductSku.where(sku: variant['sku']).first.product
              update_product_details_barcode(product, variant)
            end
            product
          end

          def update_product_details_barcode(product, variant)
            product.update_attributes(name: variant['title'], store_product_id: variant['id'])
            add_barcode_to_product(product, variant) if variant['barcode'].present? && product.product_barcodes.where(barcode: variant['barcode']).blank?
            product.generate_numeric_barcode({}) if !variant['barcode'].present? && product.product_barcodes.blank? && @credential.generating_barcodes == 'generate_numeric_barcode'
          end

          def add_barcode_to_product(product, variant)
            product.product_barcodes.destroy_all if @credential.modified_barcode_handling != 'add_to_existing'
            barcode_created = product.product_barcodes.create(barcode: variant['barcode'])
            product.product_barcodes.create(barcode: variant['barcode'], permit_shared_barcodes: true) if (begin
                                                                                                               !barcode_created.reload.present?
                                                                                                           rescue StandardError
                                                                                                             true
                                                                                                             end) && @credential.permit_shared_barcodes
            product.touch
          end

          def create_product_with_temp_sku(variant, shopify_product)
            # if sku is nil or empty
            products = Product.where(name: variant['title'])
            if products.blank?
              # if product is not found by name then create the variant
              product = create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
            else
              # product exists add temp sku if it does not exist
              if contains_temp_skus(products)
                product = get_product_with_temp_skus(products)
                product.generate_numeric_barcode({}) if !variant['barcode'].present? && product.product_barcodes.blank? && @credential.generating_barcodes == 'generate_numeric_barcode'
              else
                product = create_new_product_from_order(variant, ProductSku.get_temp_sku, shopify_product)
              end
            end
            product
          end

          def create_new_product_from_order(variant, sku, shopify_product)
            # create and import product
            if check_for_replace_product
              coupon_product = replace_product(variant['title'], sku)
              return coupon_product unless coupon_product.nil?
            end
            product = Product.create(name: variant['title'], store: @store,
                                     store_product_id: variant['id'])

            product.add_product_activity('Product Import', product.store.try(:name).to_s)
            product.product_skus.create(sku: sku)
            # get product categories
            add_tags(product, shopify_product)
            # create barcode
            create_product_barcode(product, variant)
            # get image based on the variant id
            add_image(variant, product, shopify_product)
            # update inventory level
            update_inventory(product, variant)
            # get weight
            assign_weight(product, variant)
            product.reload
            create_sync_option_for_product(product, variant)
            make_product_intangible(product)
            product.update_product_status
            product
          end

          def create_sync_option_for_product(product, variant)
            product_sync_option = product.sync_option
            if product_sync_option.nil?
              product.create_sync_option(shopify_product_variant_id: variant['id'], shopify_inventory_item_id: variant['inventory_item_id'], sync_with_shopify: true)
            else
              product_sync_option.update_attributes(shopify_product_variant_id: variant['id'], shopify_inventory_item_id: variant['inventory_item_id'], sync_with_shopify: true)
            end
          end

          def create_product_barcode(product, variant)
            case @credential.generating_barcodes
            when 'generate_from_sku'
              product.product_barcodes.create(barcode: variant['sku']) if variant['sku'].present?
            when 'import_from_shopify'
              create_barcode_from_variant(product, variant)
            when 'do_not_generate'
              barcode_created = product.product_barcodes.create(barcode: variant['barcode']) if variant['barcode'].present?
              product.product_barcodes.new(barcode: variant['barcode'], permit_shared_barcodes: true).save if variant['barcode'].present? && (begin
                                                                                                                                                  !barcode_created.reload.present?
                                                                                                                                              rescue StandardError
                                                                                                                                                true
                                                                                                                                                end) && @credential.permit_shared_barcodes
            when 'generate_numeric_barcode'
              if variant['barcode'].present?
                create_barcode_from_variant(product, variant)
              else
                product.generate_numeric_barcode({})
              end
            end
          end

          def assign_weight(product, variant)
            weight_in = { 'lb' => variant['weight'] * 16,
                          'kg' => variant['weight'] * 35.274,
                          'g' => variant['weight'] * 0.035274,
                          'oz' => variant['weight'] }
            product.weight = weight_in['lb']
            product.save
          end

          def add_tags(product, shopify_product)
            return if shopify_product['tags'].blank?

            tags = shopify_product['tags'].split(', ')
            tags.each { |tag| product.product_cats.create(category: tag) }
          end

          def add_image(variant, product, shopify_product)
            variant_image = shopify_product['images']&.select { |image| image['id'] == variant['image_id'] }&.first
            variant_image ||= shopify_product['image']
            variant_image_src = begin
                                    variant_image['src']
                                rescue StandardError
                                  nil
                                  end
            product.product_images.create(image: variant_image_src)
          end

          def assign_attr_to_variant_for_custom_item(variant, item)
            variant['sku'] = "C-" + item['id'].to_s
            variant['barcode'] = variant['sku']
            variant['weight'] = variant['grams']
            variant['inventory_quantity'] = variant['quantity']
            variant
          end

          def create_barcode_from_variant(product, variant)
            barcode = variant['barcode'].present? ? variant['barcode'] : variant['sku']
            barcode_created = product.product_barcodes.create(barcode: barcode) if barcode.present?
            if barcode.present? && (begin !barcode_created.reload.present?
                                    rescue StandardError
                                      true
                                    end) && @credential&.permit_shared_barcodes
              product.product_barcodes.new(barcode: barcode, permit_shared_barcodes: true).save
            end
          end

          def update_inventory(product, variant)
            inv_wh = product.product_inventory_warehousess.first
            inv_wh = product.product_inventory_warehousess.new if inv_wh.blank?
            inv_wh.quantity_on_hand = variant['inventory_quantity'].try(:to_i) + inv_wh.allocated_inv.to_i
            inv_wh.save
          end

          def send_products_import_complete_email(products_count)
            result = { status: true, success_imported: products_count }

            begin
                ImportMailer.send_products_import_complete_email(products_count, result, @credential).deliver
            rescue StandardError
              nil
              end
          end
        end
      end
    end
  end
end
