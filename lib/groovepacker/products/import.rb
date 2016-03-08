module Groovepacker
  module Products
    class Import
      include ProductsHelper

      def initialize(attrs={})
        @result = attrs[:result]
        @params = attrs[:params]
        @current_user = attrs[:current_user]
        @store = attrs[:store]
      end

      def import_products
      	current_tenant = Apartment::Tenant.current
        import_result = nil
    
        if @current_user.can?('import_products')
          begin
            #import if magento products
            if @store.store_type != 'Amazon'
            	handler = get_handler
              context = Groovepacker::Stores::Context.new(handler)
              import_orders_obj = ImportOrders.new
              import_orders_obj.delay(:run_at => 1.seconds.from_now).init_import(current_tenant)
              #import_result = context.delay(:run_at => 1.seconds.from_now).import_products
              import_result = context.import_products
            else
              run_import_for_amazon
            end
          rescue Exception => e
            @result['status'] = false
            @result['messages'].push(e.message)
          end
        else
          @result['status'] = false
          @result['messages'].push('You can not import products')
        end
      	return @result
      end

      private

        def get_handler
          handler = nil
          case @store.store_type
          when 'Ebay'
            handler = Groovepacker::Stores::Handlers::EbayHandler.new(@store)
          when 'Magento'
            handler = Groovepacker::Stores::Handlers::MagentoHandler.new(@store)
          when 'Magento API 2'
            handler = Groovepacker::Stores::Handlers::MagentoRestHandler.new(@store)
          when 'Shipstation'
            handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(@store)
          when 'Shipstation API 2'
            handler = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(@store)
          when 'BigCommerce'
            handler = Groovepacker::Stores::Handlers::BigCommerceHandler.new(@store)
          end
          return handler
        end

      	def run_import_for_amazon
          @amazon_credentials = AmazonCredentials.where(:store_id => @store.id)
          if @amazon_credentials.length > 0
            @credential = @amazon_credentials.first
            mws = MWS.new(:aws_access_key_id =>
                            ENV['AMAZON_MWS_ACCESS_KEY_ID'],
                          :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
                          :seller_id => @credential.merchant_id,
                          :marketplace_id => @credential.marketplace_id)
            #@result['aws-response'] = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
            #@result['aws-rewuest_status'] = mws.reports.get_report_request_list
            response = mws.reports.get_report :report_id => @params[:reportid]
    
            # _GET_MERCHANT_LISTINGS_DATA_
            # item-name, item-description, listing-id, seller-sku, price, quantity, open-date, image-url, 
            # item-is-marketplace, product-id-type, zshop-shipping-fee, item-note, item-condition,
            # zshop-category1, zshop-browse-path, zshop-storefront-feature, asin1, asin2, asin3,
            # will-ship-internationally, expedited-shipping, zshop-boldface, product-id
            # bid-for-featured-placement, add-delete, pending-quantity, fulfillment-channel

            require 'csv'
            csv = CSV.parse(response.body, :quote_char => "|")
    
            csv.each_with_index do |row, index|
              if index > 0
                product_row = row.first.split(/\t/)

                if !product_row[3].nil? && product_row[3] != ''
                  @result['total_imported'] = @result['total_imported'] + 1
                  if ProductSku.where(:sku => product_row[3]).length == 0
                    @productdb = Product.new
                    @productdb.name = product_row[0]
                    @productdb.store_product_id = product_row[2]
                    if @productdb.store_product_id.nil?
                      @productdb.store_product_id = 'not_available'
                    end

                    @productdb.product_type = 'not_used'
                    @productdb.status = 'new'
                    @productdb.store = @store
    
                    #add productdb sku
                    @productdbsku = ProductSku.new
                    @productdbsku.sku = product_row[3]
                    @productdbsku.purpose = 'primary'

                    #publish the sku to the product record
                    @productdb.product_skus << @productdbsku
    
                    #add inventory warehouse
                    inv_wh = ProductInventoryWarehouses.new
                    inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
                    @productdb.product_inventory_warehousess << inv_wh

                    #save
                    if @productdbsku.sku != nil && @productdbsku.sku != ''
                      if ProductSku.where(:sku => @productdbsku.sku).length == 0
                        #save
                        if @productdb.save
                          import_amazon_product_details(@store.id, @productdbsku.sku, @productdb.id)
                          #import_amazon_product_details(mws, @credential, @productdb.id)
                          @result['success_imported'] = @result['success_imported'] + 1
                        end
                      else
                        @result['messages'].push("sku: "+product_row[3]) unless @productdbsku.sku.nil?
                        @result['previous_imported'] = @result['previous_imported'] + 1
                      end
                    else
                      if @productdb.save
                        #import_amazon_product_details(@store.id, @productdbsku.sku, @productdb.id)
                        #import_amazon_product_details(mws, @credential, @productdb.id)
                        @result['success_imported'] = @result['success_imported'] + 1
                      end
                    end
                  else
                    @result['previous_imported'] = @result['previous_imported'] + 1
                  end
                end
              end
            end
          end
        end
    end
  end
end
