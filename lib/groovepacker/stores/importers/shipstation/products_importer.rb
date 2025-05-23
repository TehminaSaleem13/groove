# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Shipstation
        include ProductsHelper
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = build_result
            products = client.product.all
            if products.nil?
              result[:status] &= false
              result[:messages] = 'No available products.'
            else
              result[:total_imported] = products.length.to_s

              # loop through the products
              products.each do |item|
                import_result = false
                previous_import = false
                if item.sku.nil? || (item.sku == '')
                  # if sku is empty
                  if Product.find_by_name(item.name).nil?
                    # product does not exist create one with temp sku
                    import_result = create_new_product(item, ProductSku.get_temp_sku, credential)
                  else
                    # product exists add temp sku if it does not exist
                    if contains_temp_skus(Product.where(name: item.name))
                      previous_import = true
                    else
                      import_result = create_new_product(item, ProductSku.get_temp_sku, credential)
                    end
                  end
                elsif ProductSku.where(sku: item.sku).empty?
                  # valid sku but not found earlier
                  import_result = create_new_product(item, item.sku, credential)
                else
                  # sku is already found
                  previous_import = true
                end

                if previous_import
                  result[:previous_imported] = result[:previous_imported] + 1
                elsif import_result
                  result[:success_imported] = result[:success_imported] + 1
                else
                  result[:status] &= false
                  result[:messages] = 'The product information could not be saved.'
                end
              end
            end
            result
          end

          def import_single(import_hash)
            result = true
            begin
              credential = import_hash[:handler][:credential]
              client = import_hash[:handler][:store_handle]
              sku = import_hash[:product_sku]
              id = import_hash[:product_id]
              products = client.product.where('SKU' => sku)
              unless products.nil?
                product = products.first
                @product = Product.find(id)
                set_product_fields(@product, product, credential)
              end
            rescue Exception => e
              result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            result
          end

          private

          def create_new_product(item, sku, credential)
            product = Product.create(store: credential.store, store_product_id: 0,
                                     name: item.name)
            product.product_skus.create(sku: sku)
            set_product_fields(product, item, credential)
          end

          def set_product_fields(product, ssproduct, credential)
            result = false
            product.name = ssproduct.name

            unless credential.store.nil? ||
                   credential.store.inventory_warehouse_id.nil? ||
                   product.product_inventory_warehousess.pluck(:inventory_warehouse_id).include?(credential.store.inventory_warehouse_id)
              inv_wh = ProductInventoryWarehouses.new
              inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
              inv_wh.location_primary = ssproduct.warehouse_location
              product.product_inventory_warehousess << inv_wh
            end

            product.weight = if ssproduct.weight_oz.nil?
                               0
                             else
                               ssproduct.weight_oz
                             end

            result = true if product.save
            product.update_product_status
            result
          end
        end
      end
    end
  end
end
