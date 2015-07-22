module Groovepacker
  module Store
    module Importers
      module Amazon
        class ProductsImporter < Groovepacker::Store::Importers::Importer
          require 'mws-connect'

          def import
          end

          #hash expects product_sku, product_id, handler(store handle, credential)
          def import_single(import_hash)
            result = true
            begin
              credential = import_hash[:handler][:credential]
              mws = import_hash[:handler][:store_handle][:alternate_handle]

              #send request to amazon mws get matching product API
              products_xml = mws.products.get_matching_products_for_id(
                :marketplace_id=>credential.marketplace_id,
                :id_type=>'SellerSKU', 
                :id_list=>[import_hash[:product_sku]])

              require 'active_support/core_ext/hash/conversions'
              product_hash = Hash.from_xml(products_xml.to_s)

              if !product_hash.nil?
                product = Product.find(import_hash[:product_id])
                product_attributes = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']
                product_identifiers = product_hash['GetMatchingProductForIdResult']['Products']['Product']['Identifiers']
                
                Rails.logger.info('Product Identifiers: ' + product_identifiers.to_s)
                Rails.logger.info('Product Attributes: ' + product_attributes.to_s)

                if !product_attributes.nil? && !product_identifiers.nil?
                  product.name = 
                    product_attributes['Title']

                  if !product_attributes['ItemDimensions'].nil? && 
                    !product_attributes['ItemDimensions']['Weight'].nil?
                    product.weight = 
                      product_attributes['ItemDimensions']['Weight'].to_f * 16
                  end

                  if !product_attributes['PackageDimensions'].nil? &&
                    !product_attributes['PackageDimensions']['Weight'].nil?
                    product.shipping_weight = 
                      product_attributes['PackageDimensions']['Weight'].to_f * 16
                  end
                  
                  if !product_identifiers['MarketplaceASIN'].nil?
                    product.store_product_id = 
                      product_identifiers['MarketplaceASIN']['ASIN']
                  end
                  
                  if credential.import_images && 
                    !product_attributes['SmallImage'].nil? &&
                    !product_attributes['SmallImage']['URL'].nil?
                    image = ProductImage.new
                    image.image = product_attributes['SmallImage']['URL']
                    product.product_images << image
                  end

                  if credential.import_products
                    category = ProductCat.new
                    category.category =  product_attributes['ProductGroup']
                    product.product_cats << category
                  end
                  
                  #add inventory warehouse
                  inv_wh = ProductInventoryWarehouses.new
                  inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
                  product.product_inventory_warehousess << inv_wh

                  scan_pack_settings = ScanPackSetting.all.first
                  product.is_intangible = false
                  if scan_pack_settings.intangible_setting_enabled
                    unless scan_pack_settings.intangible_string.nil? && (scan_pack_settings.intangible_string.strip.equal? (''))
                      intangible_strings = scan_pack_settings.intangible_string.strip.split(",")
                      intangible_strings.each do |string|
                        if (product.name.include? (string)) || (import_hash[:product_sku].include? (string))
                          product.is_intangible = true
                          break
                        end
                      end
                    end
                  end

                  product.save
                  product.update_product_status
                else
                  Rails.logger.info('No attributes and/or identifiers for SKU: ' + 
                    import_hash[:product_sku])
                end
              else
                Rails.logger.info('No data fetched for SKU: ' + import_hash[:product_sku])
              end
            rescue Exception => e
              result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            result
          end
        end
      end
    end
  end
end