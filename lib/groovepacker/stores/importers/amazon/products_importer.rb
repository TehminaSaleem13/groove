module Groovepacker
  module Stores
    module Importers
      module Amazon
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          require 'mws-connect'

          def import
            init_common_objects
            handler = self.get_handler
            requestamazonreport
            checkamazonreportstatus
            import_all_products
          end

          def requestamazonreport
            response = @mws.reports.request_report :report_type => '_GET_MERCHANT_LISTINGS_DATA_'
            @credential.productreport_id = response.report_request_info.report_request_id
            @credential.productgenerated_report_id = nil
            @credential.save
          end

          def checkamazonreportstatus
            @report_list = @mws.reports.get_report_request_list
            @report_list.report_request_info.each do |report_request|
              report_found = true
              if report_request.report_processing_status == '_DONE_'
                @credential.productgenerated_report_id = report_request.generated_report_id
                @credential.productgenerated_report_date = report_request.completed_date
                @credential.save
              end
            end
          end

          def import_single(import_hash)

            @result = true
            begin
              @credential = import_hash[:handler][:credential]
              @mws = import_hash[:handler][:store_handle][:alternate_handle]

              #send request to amazon mws get matching product API
              products_xml = @mws.products.get_matching_products_for_id(
                :marketplace_id => @credential.marketplace_id,
                :id_type => 'SellerSKU',
                :id_list => [import_hash[:product_sku]])

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

                  if @credential.import_images &&
                    !product_attributes['SmallImage'].nil? &&
                    !product_attributes['SmallImage']['URL'].nil?
                    image = ProductImage.new
                    image.image = product_attributes['SmallImage']['URL']
                    product.product_images << image
                  end

                  if @credential.import_products
                    category = ProductCat.new
                    category.category = product_attributes['ProductGroup']
                    product.product_cats << category
                  end

                  #add inventory warehouse
                  inv_wh = ProductInventoryWarehouses.new
                  inv_wh.inventory_warehouse_id = credential.store.inventory_warehouse_id
                  product.product_inventory_warehousess << inv_wh

                  product.save
                  make_product_intangible(product)
                  product.update_product_status
                else
                  Rails.logger.info('No attributes and/or identifiers for SKU: ' +
                                      import_hash[:product_sku])
                end
              else
                Rails.logger.info('No data fetched for SKU: ' + import_hash[:product_sku])
              end
            rescue Exception => e
              @result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            @result
          end


          def import_all_products
            response = @mws.reports.get_report :report_id => @credential.productgenerated_report_id
            response = response.body.split("\n").drop(1)
            response.each_with_index do |row, index|
              @product_row = row.split("\t")
              next if @product_row[3].blank?
              @result[:total_imported] = @result[:total_imported] + 1
              generate_products 
            end
          end

          def generate_products
            if ProductSku.where(:sku => @product_row[3]).length == 0
              add_productdb
              add_productdb_sku
              add_inventry_warehouse
              save_productdb
            else
              @result[:previous_imported] = @result[:previous_imported] + 1
            end
          end

          def add_productdb
            @productdb = Product.new(name: @product_row[0], store_product_id: @product_row[2] || 'not_available', product_type: 'not_used', status: 'new')
            @productdb.store = @credential.store
          end

          def add_productdb_sku
            @productdbsku = @productdb.product_skus.build(sku: @product_row[3], purpose: 'primary')
          end

          def add_inventry_warehouse
            inv_wh = ProductInventoryWarehouses.new
            inv_wh.inventory_warehouse_id = @credential.store.inventory_warehouse_id
            @productdb.product_inventory_warehousess << inv_wh
          end

          def save_productdb
            if !ProductSku.where(:sku => @productdbsku.sku).length == 0
              @result[:messages].push(sku: @product_row[3]) unless @productdbsku.sku.nil?
              @result[:previous_imported] = @result[:previous_imported] + 1
            else  
              @productdb.save
              @result[:success_imported] = @result[:success_imported] + 1
            end
          end

          def import_amazon_product_details(store_id, product_sku, product_id)
            ProductsService::AmazonImport.call(store_id, product_sku, product_id)
          end

          private
            def init_common_objects
              handler = self.get_handler
              @mws = handler[:store_handle][:main_handle]
              @credential = handler[:credential]
              @import_item = handler[:import_item]
              @alt_mws = handler[:store_handle][:alternate_handle]
              @result = self.build_result
            end
        end
      end
    end
  end
end