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
            # requestamazonreport
            # checkamazonreportstatus
            import_all_products
            update_orders_status
          end

          # def requestamazonreport
          #   response = @mws.reports.request_report :report_type => '_GET_MERCHANT_LISTINGS_DATA_BACK_COMPAT_'
          #   @credential.productreport_id = response.report_request_info.report_request_id
          #   @credential.productgenerated_report_id = nil
          #   @credential.save
          # end

          # def checkamazonreportstatus
          #   @report_list = @mws.reports.get_report_request_list
          #   @report_list.report_request_info.each do |report_request|
          #     report_found = true
          #     if report_request.report_processing_status == '_DONE_'
          #       @credential.productgenerated_report_id = report_request.generated_report_id
          #       @credential.productgenerated_report_date = report_request.completed_date
          #       @credential.save
          #     end
          #   end
          # end

          def import_single(import_hash)
            @result = true
            begin
              @import_hash = import_hash 
              @credential = @import_hash[:handler][:credential]
              @mws = @import_hash[:handler][:store_handle][:alternate_handle]
              get_matching_products
              check_product_import_attr
            rescue Exception => e
              @result &= false
              Rails.logger.info('Error updating the product sku ' + e.to_s)
            end
            @result
          end

          def import_all_products
            csv_url = GroovS3.find_csv(Apartment::Tenant.current_tenant, 'amazon_product', @credential.store.id).url rescue nil
            file_data = open(csv_url).read().split("\n")
            response = file_data.drop(1)
            header = file_data.first.split("\t")
            response.each do |row|
              row = row.split("\t")
              @product = {}
              row.each_with_index {|p, i| @product[header[i]] = p}
              generate_product
            end
          end

          def generate_product
            if ProductSku.where(:sku => @product["seller-sku"]).length == 0
              add_productdb
              add_productdb_sku
              add_inventry_warehouse
              save_productdb
            else
              @result[:previous_imported] = @result[:previous_imported] + 1
            end
          end

          def add_productdb
            name = @product["item-name"].blank? ?  "Amazon Product" : @product["item-name"]
            @productdb = Product.new(name: name, store_product_id: @product["product-id"] || 'not_available', product_type: 'not_used', status: 'new')
            @productdb.store = @credential.store
          end

          def add_productdb_sku
            @productdbsku = @productdb.product_skus.build(sku: @product["seller-sku"], purpose: 'primary')
          end

          def add_inventry_warehouse
            inv_wh = ProductInventoryWarehouses.new
            inv_wh.inventory_warehouse_id = @credential.store.inventory_warehouse_id
            @productdb.product_inventory_warehousess << inv_wh
          end

          def save_productdb
            if !ProductSku.where(:sku => @productdbsku.sku).length == 0
              @result[:messages].push(sku: @product["seller-sku"]) unless @productdbsku.sku.nil?
              @result[:previous_imported] = @result[:previous_imported] + 1
            else  
              @productdb.save
              import_amazon_product_details(@credential.store.id, @productdbsku.sku, @productdb.id)
              @result[:success_imported] = @result[:success_imported] + 1
            end
          end

          def get_matching_products
            products_xml = @mws.products.get_matching_products_for_id(
              :marketplace_id => @credential.marketplace_id,
              :id_type => 'SellerSKU',
              :id_list => [@import_hash[:product_sku]])
            require 'active_support/core_ext/hash/conversions'
            @product_hash = Hash.from_xml(products_xml.to_s)
          end

          def check_product_import_attr
            if !@product_hash.nil?
              product_attributes_and_identifiers  
              single_import_product_attributes
            else
              Rails.logger.info('No data fetched for SKU: ' + @import_hash[:product_sku])
            end
          end

          def product_attributes_and_identifiers
            @product = Product.find(@import_hash[:product_id])
            @product_attributes = @product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']
            @product_identifiers = @product_hash['GetMatchingProductForIdResult']['Products']['Product']['Identifiers']
            Rails.logger.info('Product Identifiers: ' + @product_identifiers.to_s)
            Rails.logger.info('Product Attributes: ' + @product_attributes.to_s)
          end

          def single_import_product_attributes
            if !@product_attributes.nil? && !@product_identifiers.nil?
              add_product_attr
              add_product_image
              add_product_cat
              add_poduct_inventory_warehouses
              @product.save
              make_product_intangible(@product)
              @product.update_product_status
            else
              Rails.logger.info('No attributes and/or identifiers for SKU: ' + @import_hash[:product_sku])
            end
          end

          def add_product_attr
            @product.name = @product_attributes['Title']
            @product.weight = @product_attributes['ItemDimensions']['Weight'].to_f * 16 if !@product_attributes['ItemDimensions'].nil? && !@product_attributes['ItemDimensions']['Weight'].nil?
            package_dimentions = @product_attributes['PackageDimensions']
            @product.shipping_weight = package_dimentions['Weight'].to_f * 16 if !package_dimentions.nil? && !package_dimentions['Weight'].nil?
            @product.store_product_id = @product_identifiers['MarketplaceASIN']['ASIN'] if !@product_identifiers['MarketplaceASIN'].nil?
          end

          def add_product_image
            if @credential.import_images && !@product_attributes['SmallImage'].nil? && !@product_attributes['SmallImage']['URL'].nil?
              image = ProductImage.new(image: @product_attributes['SmallImage']['URL'])
              @product.product_images << image
            end 
          end

          def add_product_cat
            if @credential.import_products
              category = ProductCat.new(category: @product_attributes['ProductGroup'])
              @product.product_cats << category
            end
          end

          def add_poduct_inventory_warehouses
            inv_wh = ProductInventoryWarehouses.new
            inv_wh.inventory_warehouse_id = @credential.store.inventory_warehouse_id
            @product.product_inventory_warehousess << inv_wh
          end

          private
            # def init_common_objects
            #   handler = self.get_handler
            #   @mws = handler[:store_handle][:main_handle]
            #   @credential = handler[:credential]
            #   @import_item = handler[:import_item]
            #   @alt_mws = handler[:store_handle][:alternate_handle]
            #   @result = self.build_result
            # end
        end
      end
    end
  end
end