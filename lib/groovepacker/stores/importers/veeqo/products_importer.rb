# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Veeqo
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include ProductMethodsHelper
    
          def import_single_product(item)
            initialize_import_objects
            if item.present?
              begin
                product_title = item['sellable']['full_title']
                product = create_product(item)
              rescue StandardError => e
                product = nil
              end
              product.update_columns(custom_product_1: product_title, custom_product_display_1: true) if product_title.present? && product
            end
            product
          end
    
          private
  
          def initialize_import_objects
            handler = get_handler
            @credential = handler[:credential]
            @store = @credential.try(:store)
            @client = handler[:store_handle]
            @store_product_import = StoreProductImport.find_by_store_id(@store&.id)
          end
      
          def create_product(item)
            if item['sellable']['sku_code'].blank?
              product = create_product_with_temp_sku(item)
            elsif ProductSku.where(sku: item['sellable']['sku_code']).empty? && !Product.where(store_product_id: item['sellable']['product']['id']).empty?
              product = Product.where(store_product_id: item['sellable']['product']['id']).first
              product.product_skus.create(sku: item['sellable']['sku_code'])
              update_product_details_barcode(product, item)
            elsif ProductSku.where(sku: item['sellable']['sku_code']).empty?
              # if non-nil sku is not found
              product = create_new_product_from_order(item, item['sellable']['sku_code'])
            else
              product = ProductSku.where(sku: item['sellable']['sku_code']).first.product
              update_product_details_barcode(product, item)
            end
            product
          end
  
          def update_product_details_barcode(product, item)
            product.update_attributes(name: item['sellable']['full_title'], store_product_id: item['sellable']['product']['id'])
            add_barcode_to_product(product, item) if item['sellable']['upc_code'].present? && product.product_barcodes.where(barcode: item['sellable']['upc_code']).blank?
          end
  
          def add_barcode_to_product(product, item)
            barcode_created = product.product_barcodes.create(barcode: item['sellable']['upc_code'])
            product.product_barcodes.create(barcode: item['sellable']['upc_code'], permit_shared_barcodes: true) if (begin
                                                                                                                !barcode_created.reload.present?
                                                                                                            rescue StandardError
                                                                                                              true
                                                                                                              end)
            product.touch
          end
  
          def create_product_with_temp_sku(item)
            # if sku is nil or empty
            products = Product.where(name: item['sellable']['full_title'])
            if products.blank?
              # if product is not found by name then create the product
              product = create_new_product_from_order(item, ProductSku.get_temp_sku)
            end
            product
          end
  
          def create_new_product_from_order(item, sku)
            # create and import product
            if check_for_replace_product
              coupon_product = replace_product(item['sellable']['full_title'], sku)
              return coupon_product unless coupon_product.nil?
            end
            product = Product.create(name: item['sellable']['full_title'], store: @store,
                                      store_product_id: item['sellable']['product']['id'])
  
            product.add_product_activity('Product Import', product.store.try(:name).to_s)
            product.product_skus.create(sku: sku)
            # create barcode
            create_barcode_from_item(product, item)
            # get image based on the variant id
            add_image(product, item)
            # update inventory level
            update_inventory(product, item)
            # get weight
            assign_weight(product, item)
            product.reload
            make_product_intangible(product)
            product.update_product_status
            product
          end
      
          def assign_weight(product, item)
            item_weight = item['sellable']['product']['weight']
            if item_weight
              weight_in = { 'lb' => item_weight * 16,
                            'kg' => item_weight * 35.274,
                            'g' => item_weight * 0.035274,
                            'oz' => item_weight }
              product.weight = weight_in['lb']
            end
  
            product.save
          end
    
          def add_image(product, item)
            image_src = begin
                          item['sellable']['image_url']
                      rescue StandardError
                        nil
                        end
            product.product_images.create(image: image_src)
          end
    
          def create_barcode_from_item(product, item)
            if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: item['sellable']['sku_code']).empty? && item['sellable']['sku_code'].present?
              product.product_barcodes.create(barcode: item['sellable']['sku_code'])
            elsif @credential.import_upc && item['sellable']['upc_code'].present? && item['sellable']['upc_code'] != '0'
              product.product_barcodes.create(barcode: item['sellable']['upc_code'])
            end
          end
  
          def update_inventory(product, item)
            inv_wh = product.product_inventory_warehousess.first
            inv_wh = product.product_inventory_warehousess.new if inv_wh.blank?
            inv_wh.quantity_on_hand = item['sellable']['inventory']['physical_stock_level_at_all_warehouses'].try(:to_i) + inv_wh.allocated_inv.to_i
            inv_wh.save
          end
        end
      end
    end
  end
end
