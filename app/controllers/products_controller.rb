class ProductsController < ApplicationController
  before_filter :authenticate_user!
  include ProductsHelper
  def importproducts
    @store = Store.find(params[:id])
    @result = Hash.new

    @result['status'] = true
    @result['messages'] = []
    @result['total_imported'] = 0
    @result['success_imported'] = 0
    @result['previous_imported'] = 0

    import_result = nil

    if current_user.can?('import_products')
      begin
      #import if magento products
      if @store.store_type == 'Ebay'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::EbayHandler.new(@store))
        import_result = context.import_products
      elsif @store.store_type == 'Magento'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::MagentoHandler.new(@store))
        import_result = context.import_products
      elsif @store.store_type == 'Shipstation'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::ShipstationHandler.new(@store))
        import_result = context.import_products
      elsif @store.store_type == 'Shipstation API 2'
        context = Groovepacker::Store::Context.new(
          Groovepacker::Store::Handlers::ShipstationRestHandler.new(@store))
        import_result = context.import_products
      elsif @store.store_type == 'Amazon'
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
          response = mws.reports.get_report :report_id=> params[:reportid]

          # _GET_MERCHANT_LISTINGS_DATA_
          # item-name
          # item-description
          # listing-id
          # seller-sku
          # price
          # quantity
          # open-date
          # image-url
          # item-is-marketplace
          # product-id-type
          # zshop-shipping-fee
          # item-note
          # item-condition
          # zshop-category1
          # zshop-browse-path
          # zshop-storefront-feature
          # asin1
          # asin2
          # asin3
          # will-ship-internationally
          # expedited-shipping
          # zshop-boldface
          # product-id
          # bid-for-featured-placement
          # add-delete
          # pending-quantity
          # fulfillment-channel

          require 'csv'
          csv = CSV.parse(response.body,:quote_char => "|")

          csv.each_with_index do | row, index|
            if index > 0
              product_row = row.first.split(/\t/)

              if !product_row[3].nil? && product_row[3] != ''
                @result['total_imported']  = @result['total_imported'] + 1
                if ProductSku.where(:sku => product_row[3]).length  == 0
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
                    if ProductSku.where(:sku=>@productdbsku.sku).length == 0
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
    rescue Exception => e
      @result['status'] = false
      @result['messages'].push(e.message)
    end
    else
      @result['status'] = false
      @result['messages'].push('You can not import products')
    end
    # puts @result.inspect
    if !import_result.nil?
      import_result[:messages].each do |message|
        @result['messages'].push(message)
      end
      @result['total_imported'] = import_result[:total_imported]
      @result['success_imported'] = import_result[:success_imported]
      @result['previous_imported'] = import_result[:previous_imported]
    end

    respond_to do |format|
      format.json { render json: @result}
    end

  end

  def importimages
    @store = Store.find(params[:id])
    @result = Hash.new

    @result['status'] = true
    @result['messages'] = []
    @result['total_imported'] = 0
    @result['success_imported'] = 0
    @result['previous_imported'] = 0

    import_result = nil
    puts current_user.inspect
    if current_user.can?('import_products')
      begin
        if @store.store_type == 'Shipstation'
          puts "in importimages"
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::ShipstationHandler.new(@store))
          puts "returned from images_importer"
          import_result = context.import_images
        end
      rescue Exception => e
        @result['status'] = false
        @result['messages'].push(e.message)
      end
    else
      @result['status'] = false
      @result['messages'].push('You can not import images')
    end
    # puts @result.inspect
    if !import_result.nil?
      import_result[:messages].each do |message|
        @result['messages'].push(message)
      end
      @result['total_imported'] = import_result[:total_imported]
      @result['success_imported'] = import_result[:success_imported]
      @result['previous_imported'] = import_result[:previous_imported]
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  # PS:Where is this used?
  def import_product_details
    if current_user.can?('import_products')
      @store = Store.find(params[:store_id])
      @amazon_credentials = AmazonCredentials.where(:store_id => @store.id)

      if @amazon_credentials.length > 0
        @credential = @amazon_credentials.first

        require 'mws-connect'

        mws = Mws.connect(
            merchant: @credential.merchant_id,
            access: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
            secret: ENV['AMAZON_MWS_SECRET_ACCESS_KEY']
          )
        products_api = mws.products.get_matching_products_for_id(:marketplace_id=>@credential.marketplace_id,
          :id_type=>'SellerSKU', :id_list=>['T-TOOL'])
        require 'active_support/core_ext/hash/conversions'
        product_hash = Hash.from_xml(products_api.to_s)
        # product_hash = from_xml(products_api)
        # puts product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['SmallImage']['URL']
        raise
        # response = mws.orders.get_matching_product_for_id :id_type=>'SellerSKU', :seller_sku => ["12345678"],
        #   :marketplace_id => @credential.marketplace_id
        # # response = mws.orders.list_orders :last_updated_after => 2.months.ago,
        # #   :order_status => ['Unshipped', 'PartiallyShipped']
        # response.products
        @products = Product.where(:store_id => params[:store_id])
        @products.each do |product|
          #import_amazon_product_details(mws, @credential, product.id)
        end
      end

    end
  end

  def requestamazonreport
    @amazon_credentials = AmazonCredentials.where(:store_id => params[:id])
    @result = Hash.new
    @result['status'] = false
    if @amazon_credentials.length > 0

      @credential = @amazon_credentials.first

      mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
          :seller_id => @credential.merchant_id,
        :marketplace_id => @credential.marketplace_id)

      response = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
      @credential.productreport_id = response.report_request_info.report_request_id
      @credential.productgenerated_report_id = nil

      if @credential.save
        @result['status'] = true
        @result['requestedreport_id'] = @credential.productreport_id
      end

    end

      respond_to do |format|
        format.json { render json: @result}
      end
  end

  def checkamazonreportstatus
    @amazon_credentials = AmazonCredentials.where(:store_id => params[:id])
    @result = Hash.new
    @result['status'] = false
    report_found = false
    if @amazon_credentials.length > 0

      @credential = @amazon_credentials.first

      mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
        :seller_id => @credential.merchant_id,
        :marketplace_id => @credential.marketplace_id)

      @report_list = mws.reports.get_report_request_list
      @report_list.report_request_info.each do |report_request|
        if report_request.report_request_id == @credential.productreport_id
          report_found = true
          if report_request.report_processing_status == '_SUBMITTED_'
            @result['status'] = true
            @result['report_status'] = 'Report has been submitted successfully. '+
              'It is still being generated by the server.'
          elsif report_request.report_processing_status == '_DONE_'
            @result['report_status'] = 'Report is generated successfully.'

            @credential.productgenerated_report_id = report_request.generated_report_id
            @credential.productgenerated_report_date = report_request.completed_date
            if @credential.save
              @result['status'] = true
              @result['requestedreport_id'] = @credential.productreport_id
              @result['generated_report_id'] = report_request.generated_report_id
              @result['generated_report_date'] = report_request.completed_date
            end
          elsif report_request.report_processing_status == '_INPROGRESS_'
            @result['status'] = true
            @result['report_status'] = 'Report is in progress. It will be ready in few moments.'
          else
            @result['response'] = report_request
            #store generated report id
          end
        end
      end

      if !report_found
        @result['status'] = true
        @result['report_status'] = 'Report is not found. Please check back in few moments.'
      end
    end

      respond_to do |format|
        format.json { render json: @result}
      end
  end
  # Get list of products based on limit and offset. It is by default sorted by updated_at field
  # If sort parameter is passed in then the corresponding sort filter will be used to sort the list
  # The expected parameters in params[:sort] are 'updated_at', name', 'sku', 'status', 'barcode', 'location_primary'
  # and quantity. The API supports to provide order of sorting namely ascending or descending. The parameter can be
  # passed in using params[:order] = 'ASC' or params[:order] ='DESC' [Note: Caps letters] By default, if no order is mentioned,
  # then the API considers order to be descending.The API also supports a product status filter.
  # The filter expects one of the following parameters in params[:filter] 'all', 'active', 'inactive', 'new'.
  # If no filter is passed, then the API will default to 'active'
  # if you would like to get Kits, specify params[:is_kit] to 1. it will return product kits and the corresponding skus
  #
  def getproducts
    @result = Hash.new
    @result[:status] = true
    @products = do_getproducts
    @result['products'] = make_products_list(@products)
    @result['products_count'] = get_products_count()
    respond_to do |format|
          format.json { render json: @result}
    end
  end

  def create
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('add_edit_products')
      product = Product.new
      product.name = "New Product"
      product.store_id = Store.where(:store_type=>'system').first.id
      product.store_product_id = 0
      product_inv_wh = ProductInventoryWarehouses.new
      product_inv_wh.inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id
      product.product_inventory_warehousess << product_inv_wh
      product.save

      product.store_product_id = product.id
      product.save
      @result['product'] = product
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to create a product')
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def duplicateproduct

    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @products = list_selected_products
      unless @products.nil?
        @products.each do|product|
          #copy product
          @product = Product.find(product["id"])

          @newproduct = @product.dup
          index = 0
          @newproduct.name = @product.name+" "+index.to_s
          @productslist = Product.where(:name=>@newproduct.name)
          begin
            index = index + 1
            #todo: duplicate sku, images, categories associated with product too.
            @newproduct.name = @product.name+" "+index.to_s
            @productslist = Product.where(:name=>@newproduct.name)
          end while(!@productslist.nil? && @productslist.length > 0)

          #copy barcodes
          @product.product_barcodes.each do |barcode|
            index = 0
            newbarcode = barcode.barcode+" "+index.to_s
            barcodeslist = ProductBarcode.where(:barcode=>newbarcode)
            begin
              index = index + 1
              #todo: duplicate sku, images, categories associated with product too.
              newbarcode = barcode.barcode+" "+index.to_s
              barcodeslist = ProductBarcode.where(:barcode=>newbarcode)
            end while(!barcodeslist.nil? && barcodeslist.length > 0)

            newbarcode_item = ProductBarcode.new
            newbarcode_item.barcode = newbarcode
            @newproduct.product_barcodes << newbarcode_item
          end

          #copy skus
          @product.product_skus.each do |sku|
            index = 0
            newsku = sku.sku+" "+index.to_s
            skuslist = ProductSku.where(:sku=>newsku)
            begin
              index = index + 1
              #todo: duplicate sku, images, categories associated with product too.
              newsku = sku.sku+" "+index.to_s
              skuslist = ProductSku.where(:sku=>newsku)
            end while(!skuslist.nil? && skuslist.length > 0)

            newsku_item = ProductSku.new
            newsku_item.sku = newsku
            newsku_item.purpose = sku.purpose
            @newproduct.product_skus << newsku_item
          end

          #copy images
          @product.product_images.each do |image|
            newimage = ProductImage.new
            newimage = image.dup
            @newproduct.product_images << newimage
          end

          #copy categories
          @product.product_cats.each do |category|
            newcategory = ProductCat.new
            newcategory = category.dup
            @newproduct.product_cats << newcategory
          end

          #copy product kit items
          @product.product_kit_skuss.each do |sku|
            new_kit_sku = ProductKitSkus.new
            new_kit_sku = sku.dup
            @newproduct.product_kit_skuss << new_kit_sku
          end

          #copy product inventory warehouses
          @product.product_inventory_warehousess.each do |warehouse|
            new_warehouse = ProductInventoryWarehouses.new
            new_warehouse = warehouse.dup
            @newproduct.product_inventory_warehousess << new_warehouse
          end


          if !@newproduct.save(:validate => false)
            @result['status'] = false
            @result['messages'] = @newproduct.errors.full_messages
          end
        end
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to duplicate products')
    end
    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteproduct
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('delete_products')
      @products = list_selected_products
      unless @products.nil?
        @products.each do|product|
          @product = Product.find(product["id"])
          @product.order_items.each do |order_item|
            order_item.order.status = "onhold"
            order_item.order.save
            order_item.order.addactivity("An item with Name #{@product.name} and " + 
              "SKU #{@product.primary_sku} has been deleted", 
              current_user.username, 
              "deleted_item"
            )
            order_item.destroy
          end

          ProductKitSkus.where(option_product_id: @product.id).each do |product_kit_sku|
            product_kit_sku.product.status = "new"
            product_kit_sku.product.save
            product_kit_sku.product.product_kit_activities.create(
              activity_message: "An item with Name #{@product.name} and " + 
              "SKU #{@product.primary_sku} has been deleted", 
              username: current_user.username, 
              activity_type: "deleted_item"
            )
            product_kit_sku.destroy
          end

          if @product.destroy
            @result['status'] &= true
          else
            @result['status'] &= false
            @result['messages'] = @product.errors.full_messages
          end
        end
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to delete products')
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def print_receiving_label
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    products = list_selected_products
    @products = []
    unless products.nil?
      products.each do |product|
        list_product = Product.find(product['id'])
        @products << list_product
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json {
        time = Time.now
        file_name = 'receiving_label_'+time.strftime('%d_%b_%Y')
        result['receiving_label_path'] = '/pdfs/'+ file_name + '.pdf'
        render :pdf => file_name,
               :template => 'products/print_receiving_label',
               :orientation => 'portrait',
               :page_height => '6in',
               :save_only => true,
               :page_width => '4in',
               :margin => {:top => '1',
                           :bottom => '0',
                           :left => '2',
                           :right => '2'},
               :handlers =>[:erb],
               :formats => [:html],
               :save_to_file => Rails.root.join('public','pdfs', "#{file_name}.pdf")

        render json: result
      }
    end
  end

  def generatebarcode
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('add_edit_products')
      @products = list_selected_products
      unless @products.nil?
        @products.each do|product|
          @product = Product.find(product["id"])
          if @product.product_barcodes.first.nil?
            sku = @product.product_skus.first
            unless sku.nil?
              barcode = @product.product_barcodes.new
              barcode.barcode = sku.sku
              unless barcode.save
                @result['status'] &= false
                @result['messages'].push(barcode.errors.full_messages)
              end
            end
          end
          @product.update_product_status
        end
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to generate barcodes')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  # For search pass in parameter params[:search] and a params[:limit] and params[:offset].
  # If limit and offset are not passed, then it will be default to 10 and 0
  def search
    @result = Hash.new
    @result['status'] = true
  if !params[:search].nil? && params[:search] != ''

    @products = do_search(false)
    @result['products'] = make_products_list(@products['products'])
    @result['products_count'] = get_products_count
    @result['products_count']['search'] = @products['count']
  else
    @result['status'] = false
    @result['message'] = 'Improper search string'
  end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def changeproductstatus
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @products = list_selected_products
      unless @products.nil?
        @products.each do|product|
          @product = Product.find(product["id"])
          current_status = @product.status
          @product.status = params[:status]
          if @product.save
             @product.reload
            if @product.status !='inactive'
              if !@product.update_product_status && params[:status] == 'active'
                @result['status'] &= false
                if @product.is_kit == 1
                  @result['messages'].push('There was a problem changing kit status for '+
                   @product.name + '. Reason: In order for a Kit to be Active it needs to '+
                   'have at least one item and every item in the Kit must be Active.')
                else
                  @result['messages'].push('There was a problem changing product status for '+
                   @product.name + '. Reason: In order for a product to be Active it needs to '+
                   'have at least one SKU and one barcode.')
                end
                @product.status = current_status
                @product.save
              end
            end
          else
            @result['status'] &= false
            @result['messages'].push('There was a problem changing products status for '+@product.name)
          end
        end
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to edit product status')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def getdetails
    @result = Hash.new
    @product = nil
    if !params[:id].nil?
      @product = Product.find_by_id(params[:id])
    else
      prod_barcodes = ProductBarcode.where(:barcode=>params[:barcode])
      if prod_barcodes.length > 0
        @product = prod_barcodes.first.product
      end
    end
    if !@product.nil?
      @product.reload
      store_id = @product.store_id
      stores = Store.where(:id=>store_id)
      if !stores.nil?
        @store = stores.first
      end
      general_setting = GeneralSetting.all.first
      amazon_products = AmazonCredentials.where(:store_id=>store_id)
      if !amazon_products.nil?
        @amazon_product = amazon_products.first
      end

      @result['product'] = Hash.new
      @result['product']['amazon_product'] = @amazon_product
      @result['product']['store'] = @store
      @result['product']['basicinfo'] = @product
      @result['product']['product_weight_format'] = GeneralSetting.get_product_weight_format
      @result['product']['weight'] = @product.get_weight
      @result['product']['shipping_weight'] = @product.get_shipping_weight
      @result['product']['skus'] = @product.product_skus.order("product_skus.order ASC")
      @result['product']['cats'] = @product.product_cats
      @result['product']['images'] = @product.product_images.order("product_images.order ASC")
      @result['product']['barcodes'] = @product.product_barcodes.order("product_barcodes.order ASC")
      @result['product']['inventory_warehouses'] = []
      @product.product_inventory_warehousess.each do |inv_wh|
        if UserInventoryPermission.where(
            :user_id => current_user.id,
            :inventory_warehouse_id => inv_wh.inventory_warehouse_id,
            :see => true
        ).length > 0
          inv_wh_result = Hash.new
          inv_wh_result['info'] = inv_wh.attributes
          inv_wh_result['info']['sold_inv'] = SoldInventoryWarehouse.sum(
              :sold_qty,
              :conditions => {:product_inventory_warehouses_id => inv_wh.id}
          )
          unless general_setting.low_inventory_alert_email
            inv_wh_result['info']['product_inv_alert'] = false
          end
          unless inv_wh_result['info']['product_inv_alert']
            inv_wh_result['info']['product_inv_alert_level'] = general_setting.default_low_inventory_alert_limit
          end
          inv_wh_result['warehouse_info'] = nil
          unless inv_wh.inventory_warehouse_id.nil?
            inv_wh_result['warehouse_info'] = InventoryWarehouse.find(inv_wh.inventory_warehouse_id)
          end
          @result['product']['inventory_warehouses'] << inv_wh_result
        end
      end
      #@result['product']['productkitskus'] = @product.product_kit_skuss
      @result['product']['productkitskus'] = []
      if @product.is_kit
        @product.product_kit_skuss.each do |kit|
          option_product = Product.find(kit.option_product_id)

          kit_sku = Hash.new
          kit_sku['name'] = option_product.name
          if option_product.product_skus.length > 0
            kit_sku['sku'] = option_product.primary_sku
          end
          kit_sku['qty'] = kit.qty
          kit_sku['qty_on_hand'] = 0
          option_product.product_inventory_warehousess.each do |inventory|
            kit_sku['qty_on_hand'] +=  inventory.available_inv.to_i
          end
          kit_sku['packing_order'] = kit.packing_order
          kit_sku['option_product_id'] = option_product.id
          @result['product']['productkitskus'].push(kit_sku)
        end
        @result['product']['productkitskus'] =
          @result['product']['productkitskus'].sort_by {|hsh| hsh['packing_order']}
        @result['product']['product_kit_activities'] = @product.product_kit_activities
        @result['product']['unacknowledged_kit_activities'] = @product.unacknowledged_kit_activities
      end

      if @product.product_skus.length > 0
        @result['product']['pendingorders'] = Order.where(:status=>'awaiting').where(:status=>'onhold').
          where(:sku=>@product.product_skus.first.sku)
      else
        @result['product']['pendingorders'] = nil
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def addproducttokit
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @kit = Product.find_by_id(params[:kit_id])

      if !@kit.is_kit
        @result['messages'].push("Product with id="+@kit.id+"is not a kit")
        @result['status'] &= false
      else
        if params[:product_ids].nil?
          @result['messages'].push("No item sent in the request")
          @result['status'] &= false
        else
          items = Product.find(params[:product_ids])
          items.each do |item|
            if item.nil?
              @result['messages'].push("Item does not exist")
              @result['status'] &= false
            else
              product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(item.id, @kit.id)
              if product_kit_sku.nil?
                @productkitsku = ProductKitSkus.new
                @productkitsku.option_product_id = item.id
                @productkitsku.qty = 1
                @kit.product_kit_skuss << @productkitsku
                if @kit.save
                  @productkitsku.reload
                  @productkitsku.add_product_in_order_items
                else
                  @result['messages'].push("Could not save kit with sku: "+@product_skus.first.sku)
                  @result['status'] &= false
                end
              else
                @result['messages'].push("The product with id #{item.id} has already been added to the kit")
                @result['status'] &= false
              end
              item.update_product_status
            end
          end
        end

      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to add a product to a kit')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def removeproductsfromkit
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @kit = Product.find_by_id(params[:kit_id])

      if @kit.is_kit
        if params[:kit_products].nil?
          @result['messages'].push("No sku sent in the request")
          @result['status'] &= false
        else
          params[:kit_products].reject!{|a| a==""}
          params[:kit_products].each do |kit_product|
        product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(kit_product,@kit.id)

          if product_kit_sku.nil?
            @result['messages'].push("Product #{kit_product} not found in item")
            @result['status'] &= false
          else
            unless product_kit_sku.destroy
              @result['messages'].push("Product #{kit_product} could not be removed fronm kit")
              @result['status'] &= false
            end
          end
          end
        end
        @kit.update_product_status
      else
        @result['messages'].push("Product with id="+@kit.id+"is not a kit")
        @result['status'] &= false
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to remove products from kits')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end
  def updateproduct
    @result = Hash.new
    @product = Product.find(params[:basicinfo][:id])
    @result['status'] = true
    @result['messages'] = []
    @result['params'] = params

    if !@product.nil?
      if current_user.can?('add_edit_products') ||
          (session[:product_edit_matched_for_current_user] && session[:product_edit_matched_for_products].include?(@product.id))
        @product.reload
        #Update Basic Info
        @product.disable_conf_req = params[:basicinfo][:disable_conf_req]
        @product.is_kit = params[:basicinfo][:is_kit]
        @product.is_skippable = params[:basicinfo][:is_skippable]
        @product.record_serial= params[:basicinfo][:record_serial]
        @product.kit_parsing = params[:basicinfo][:kit_parsing]
        @product.name = params[:basicinfo][:name]
        @product.pack_time_adj = params[:basicinfo][:pack_time_adj]
        @product.packing_placement = params[:basicinfo][:packing_placement] if params[:basicinfo][:packing_placement].is_a?(Integer)
        @product.product_type = params[:basicinfo][:product_type]
        @product.spl_instructions_4_confirmation = params[:basicinfo][:spl_instructions_4_confirmation]
        @product.spl_instructions_4_packer = params[:basicinfo][:spl_instructions_4_packer]
        @product.status = params[:basicinfo][:status]
        @product.store_id = params[:basicinfo][:store_id]
        @product.store_product_id = params[:basicinfo][:store_product_id]

        @product.weight = get_product_weight(params[:weight])
        @product.shipping_weight = get_product_weight(params[:shipping_weight])

        if !@product.save
          @result['status'] &= false
        end

        #Update product inventory warehouses
        #check if a product inventory warehouse is defined.
        product_inv_whs = ProductInventoryWarehouses.where(:product_id=>@product.id)

        if product_inv_whs.length > 0
          product_inv_whs.each do |inv_wh|
            if UserInventoryPermission.where(
                :user_id => current_user.id,
                :inventory_warehouse_id => inv_wh.inventory_warehouse_id,
                :edit => true
            ).length > 0
              found_inv_wh = false
              unless params[:inventory_warehouses].nil?
                params[:inventory_warehouses].each do |wh|
                  if wh["info"]["id"] == inv_wh.id
                    found_inv_wh = true
                  end
                end
              end
              if found_inv_wh == false
                if !inv_wh.destroy
                  @result['status'] &= false
                end
              end
            end
          end
        end

        #Update product inventory warehouses
        #check if a product category is defined.
        if !params[:inventory_warehouses].nil?
          general_setting = GeneralSetting.all.first
          params[:inventory_warehouses].each do |wh|
            if UserInventoryPermission.where(
                :user_id => current_user.id,
                :inventory_warehouse_id => wh['warehouse_info']['id'],
                :edit => true
            ).length > 0
              if !wh["info"]["id"].nil?
                product_inv_wh = ProductInventoryWarehouses.find(wh["info"]["id"])
                product_inv_wh.available_inv = wh["info"]["available_inv"]
                product_inv_wh.location_primary = wh["info"]["location_primary"]
                product_inv_wh.location_secondary = wh["info"]["location_secondary"]
                product_inv_wh.location_tertiary = wh["info"]["location_tertiary"]
                if general_setting.low_inventory_alert_email
                  if !product_inv_wh.product_inv_alert && product_inv_wh.product_inv_alert_level != wh["info"]["product_inv_alert_level"]
                    product_inv_wh.product_inv_alert = true
                  else
                    product_inv_wh.product_inv_alert = wh["info"]["product_inv_alert"]
                  end
                  product_inv_wh.product_inv_alert_level = wh["info"]["product_inv_alert_level"]
                end
                unless product_inv_wh.save
                  @result['status'] &= false
                end
              elsif !wh["warehouse_info"]["id"].nil?
                product_inv_wh = ProductInventoryWarehouses.new
                product_inv_wh.product_id = @product.id
                product_inv_wh.inventory_warehouse_id = wh["warehouse_info"]["id"]
                unless product_inv_wh.save
                  @result['status'] &= false
                end
              end
            end
          end
        end


        #Update product categories
        #check if a product category is defined.
        product_cats = ProductCat.where(:product_id=>@product.id)

        if product_cats.length > 0
          product_cats.each do |productcat|
            found_cat = false

            if !params[:cats].nil?
              params[:cats].each do |cat|
                if cat["id"] == productcat.id
                  found_cat = true
                end
              end
            end

            if found_cat == false
              if !productcat.destroy
                @result['status'] &= false
              end
            end
          end
        end

        if !params[:cats].nil?
          params[:cats].each do |category|
            if !category["id"].nil?
              product_cat = ProductCat.find(category["id"])
              product_cat.category = category["category"]
              if !product_cat.save
                @result['status'] &= false
              end
            else
              product_cat = ProductCat.new
              product_cat.category = category["category"]
              product_cat.product_id = @product.id
              if !product_cat.save
                @result['status'] &= false
              end
            end
          end
        end

        #Update product skus
        #check if a product sku is defined.

        product_skus = ProductSku.where(:product_id=>@product.id)

        if product_skus.length > 0
          product_skus.each do |productsku|
            found_sku = false

            if !params[:skus].nil?
              params[:skus].each do |sku|
                if sku["id"] == productsku.id
                  found_sku = true
                end
              end
            end
            if found_sku == false
              if !productsku.destroy
                @result['status'] &= false
              end
            end
          end
        end
        if !params[:skus].nil?
          order = 0
          params[:skus].each do |sku|
            if !sku["id"].nil?
              product_sku = ProductSku.find(sku["id"])
              product_sku.sku = sku["sku"]
              product_sku.purpose = sku["purpose"]
              product_sku.order = order
              if !product_sku.save
                @result['status'] &= false
              end
            else
              if sku["sku"]!='' && ProductSku.where(:sku => sku["sku"]).length == 0
                product_sku = ProductSku.new
                product_sku.sku = sku["sku"]
                product_sku.purpose = sku["purpose"]
                product_sku.product_id = @product.id
                product_sku.order = order
                if !product_sku.save
                  @result['status'] &= false
                end
              else
                @result['status'] &= false
                @result['message'] = "Sku "+sku["sku"]+" already exists"
              end

            end
            order = order + 1
          end
        end

        #Update product barcodes
        #check if a product barcode is defined.
        product_barcodes = ProductBarcode.where(:product_id=>@product.id)
        product_barcodes.reload
        if product_barcodes.length > 0
          product_barcodes.each do |productbarcode|
            found_barcode = false

            if !params[:barcodes].nil?
              params[:barcodes].each do |barcode|
                if barcode["id"] == productbarcode.id
                  found_barcode = true
                end
              end
            end

            if found_barcode == false
              if !productbarcode.destroy
                @result['status'] &= false
              end
            end
          end
        end

        #Update product barcodes
        #check if a product barcode is defined
        if !params[:barcodes].nil?
          order = 0
          params[:barcodes].each do |barcode|
            if !barcode["id"].nil?
              product_barcode = ProductBarcode.find(barcode["id"])
              product_barcode.barcode = barcode["barcode"]
              product_barcode.order = order
              if !product_barcode.save
                @result['status'] &= false
              end
            else
              if barcode["barcode"]!='' && ProductBarcode.where(:barcode => barcode["barcode"]).length == 0
                product_barcode = ProductBarcode.new
                product_barcode.barcode = barcode["barcode"]
                product_barcode.order = order
                product_barcode.product_id = @product.id
                if !product_barcode.save
                  @result['status'] &= false
                end
              else
                @result['status'] &= false
                @result['message'] = "Barcode "+barcode["barcode"]+" already exists"
              end
            end
            order = order + 1
          end
        end

        #Update product barcodes
        #check if a product barcode is defined.
        product_images = ProductImage.where(:product_id=>@product.id)

        if product_images.length > 0
          product_images.each do |productimage|
            found_image = false

            if !params[:images].nil?
              params[:images].each do |image|
                if image["id"] == productimage.id
                  found_image = true
                end
              end
            end

            if found_image == false
              if !productimage.destroy
                @result['status'] &= false
              end
            end
          end
        end

        #Update product barcodes
        #check if a product barcode is defined
        if !params[:images].nil?
          order = 0
          params[:images].each do |image|
            if !image["id"].nil?
              product_image = ProductImage.find(image["id"])
              product_image.image = image["image"]
              product_image.caption = image["caption"]
              product_image.order = order
              if !product_image.save
                @result['status'] &= false
              end
            else
              product_image = ProductImage.new
              product_image.image = image["image"]
              product_image.caption = image["caption"]
              product_image.product_id = @product.id
              product_image.order = order
              if !product_image.save
                @result['status'] &= false
              end
            end
            order = order + 1
          end
        end

        #if product is a kit, update product_kit_skus
        if !params[:productkitskus].nil?
          params[:productkitskus].each do |kit_product|
            actual_product = ProductKitSkus.where(:option_product_id => kit_product["option_product_id"], :product_id => @product.id)
            if actual_product.length > 0
              actual_product = actual_product.first
              actual_product.qty = kit_product["qty"]
              actual_product.packing_order = kit_product["packing_order"]
              actual_product.save
            end
          end
        end


        @product.update_product_status
      else
        @result['status'] = false
        @result['message'] = 'You do not have enough permissions to update a product'
      end
    else
      @result['status'] = false
      @result['message'] = 'Cannot find product information.'
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  #params[:id]
  def generate_barcode_slip
    @product = Product.find(params[:id])

    respond_to do |format|
      format.html
      format.pdf {
        render :pdf => "file_name",
        :template => 'products/generate_barcode_slip.html.erb',
        :orientation => 'Portrait',
        :page_height => '1in',
        :page_width => '3in',
        :margin => {:top => '0',
                    :bottom => '0',
                    :left => '0',
                    :right => '0'}
       }
    end
  end

  def updateproductlist
    @result = Hash.new
    @result['status'] = true

    if current_user.can?('add_edit_products')
      @product = Product.find_by_id(params[:id])
      if @product.nil?
        @result['status'] = false
        @result['error_msg'] ="Cannot find Product"
      else
        updatelist(@product,params[:var],params[:value])
      end
    else
      @result['status'] = false
      @result['error_msg'] = 'You do not have enough permissions to edit product list'
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  #This action will remove the entry for this product (the Alias) and the SKU of this new
  #product will be added to the list of skus for the existing product that the user is linking it to.
  #Any product can be turned into an alias, it doesn’t have to have the status of new, although most if the time it probably will.
  #The operation can not be undone.
  #If you had a situation where the newly imported product was actually the one you wanted to keep you could
  #find the original product and make it an alias of the new product...
  def setalias
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products') && current_user.can?('delete_products')
      @product_orig = Product.find(params[:product_orig_id])
      skus_len = @product_orig.product_skus.all.length
      barcodes_len = @product_orig.product_barcodes.all.length
      logger.info
      @product_aliases = Product.find_all_by_id(params[:product_alias_ids])
      if @product_aliases.length > 0
        @product_aliases.each do |product_alias|
          #all SKUs of the alias will be copied. dont use product_alias.product_skus
          @product_skus = ProductSku.where(:product_id=>product_alias.id)
          @product_skus.each do |alias_sku|
            alias_sku.product_id = @product_orig.id
            alias_sku.order = skus_len
            skus_len+=1
            if !alias_sku.save
              result['status'] &= false
              result['messages'].push('Error saving Sku for sku id'+alias_sku.id.to_s)
            end
          end

          @product_barcodes = ProductBarcode.where(:product_id=>product_alias.id)
          @product_barcodes.each do |alias_barcode|
            alias_barcode.product_id = @product_orig.id
            alias_barcode.order = barcodes_len
            barcodes_len+=1
            if !alias_barcode.save
              result['status'] &= false
              result['messages'].push('Error saving Barcode for barcode id'+alias_barcode.id)
            end
          end

          #update order items of aliased products to original products
          @order_items = OrderItem.where(:product_id=>product_alias.id)
          @order_items.each do |order_item|
            order_item.product_id = @product_orig.id
            if !order_item.save
              result['status'] &= false
              result['messages'].push('Error saving order item with id'+order_item.id)
            end
          end

          #update kit. Replace the alias product with original product
          product_kit_skus = ProductKitSkus.where(option_product_id: product_alias.id)
          product_kit_skus.each do |product_kit_sku|
            product_kit_sku.option_product_id = @product_orig.id
            unless product_kit_sku.save
              result['status'] &= false
              result['messages'].push('Error replacing aliased product in the kits')
            end
          end

          #destroy the aliased object
          if !product_alias.destroy
            result['status'] &= false
            result['messages'].push('Error deleting the product alias id:'+product_alias.id)
          end
        end
        @product_orig.set_product_status
      else
        @result['status'] = false
        @result['messages'].push('No products found to alias')
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to set product alias')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def addimage
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @product = Product.find(params[:product_id])
      if !@product.nil? && !params[:product_image].nil?
        @image = ProductImage.new

          csv_directory = "public/images"
          file_name = Time.now.to_s+params[:product_image].original_filename
          path = File.join(csv_directory, file_name )
          File.open(path, "wb") { |f| f.write(params[:product_image].read) }
          @image.image = "/images/"+file_name
        @image.caption = params[:caption] if !params[:caption].nil?
        @product.product_images << @image
        if !@product.save
          @result['status'] = false
          @result['messages'].push("Adding image failed")
        end
      else
          @result['status'] = false
          @result['messages'].push("Invalid data sent to the server")
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to add image to a product')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end

  end

  #input params[:id] gives product id params[:inv_wh_id] gives inventory warehouse id
  #params[:inventory_count] contains the inventory count from the recount
  #params[:method] this can contain two options: 'recount' or 'receive'
  #PUT request and it updates the available inventory if method is recount
  # or adds to the available inventory if method is receive if the product is
  #not associated with the inventory warehouse, then it automatically associates it and
  #sets the value.
  def adjust_available_inventory
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    unless params[:id].nil? || params[:inv_wh_id].nil? ||
      params[:method].nil?
      product = Product.find(params[:id])
      unless product.nil?
        product_inv_whs = ProductInventoryWarehouses.where(:product_id=> product.id).
          where(:inventory_warehouse_id=>params[:inv_wh_id])

        unless product_inv_whs.length == 1
          product_inv_wh = ProductInventoryWarehouses.new
          product_inv_wh.inventory_warehouse_id = params[:inv_wh_id]
          product.product_inventory_warehousess << product_inv_wh
          product.save
          product_inv_whs.reload
        end

        unless params[:inventory_count].blank?
          if params[:method] == 'recount'
            product_inv_whs.first.available_inv = params[:inventory_count]
          elsif params[:method] == 'receive'
            product_inv_whs.first.available_inv =
                product_inv_whs.first.available_inv + (params[:inventory_count].to_i)
          else
            result['status'] &= false
            result['error_messages'].push("Invalid method passed in parameter.
          Only 'receive' and 'recount' are valid. Passed in parameter: "+params[:method])
          end
        end
        unless params[:location_primary].blank?
          product_inv_whs.first.location_primary = params[:location_primary]
        end
        unless params[:location_secondary].blank?
          product_inv_whs.first.location_secondary = params[:location_secondary]
        end
        unless params[:location_tertiary].blank?
          product_inv_whs.first.location_tertiary = params[:location_tertiary]
        end
        product_inv_whs.first.save

      else
      result['status'] &= false
      result['error_messages'].push('Cannot find product with id: ' +params[:id])
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot recount inventory without product id and
          inventory_warehouse_id')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  private

  def get_product_weight(weight)
    if GeneralSetting.get_product_weight_format=='English'
      @lbs =  16 * weight[:lbs].to_i
      @oz = weight[:oz].to_f
      @lbs + @oz
    else
      @kgs = 1000 * weight[:kgs].to_i
      @gms = weight[:gms].to_f
      (@kgs + @gms) * 0.035274
    end
  end

  def do_search(results_only = true)
    limit = 10
    offset = 0
    sort_key = 'updated_at'
    sort_order = 'DESC'
    supported_sort_keys = ['updated_at', 'name', 'sku',
                           'status', 'barcode', 'location_primary','location_secondary','location_tertiary','location_name','cat','qty', 'store_type' ]
    supported_order_keys = ['ASC', 'DESC' ] #Caps letters only

    sort_key = params[:sort] if !params[:sort].nil? &&
        supported_sort_keys.include?(params[:sort].to_s)

    sort_order = params[:order] if !params[:order].nil? &&
        supported_order_keys.include?(params[:order].to_s)

    # Get passed in parameter variables if they are valid.
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0
    search = ActiveRecord::Base::sanitize('%'+params[:search]+'%')
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    kit_query = ''
    query_add = ''

    is_kit = params[:is_kit].to_i if !params[:is_kit].nil?  &&
        supported_kit_params.include?(params[:is_kit])
    unless is_kit == -1
      kit_query = 'AND products.is_kit='+is_kit.to_s+' '
    end
    unless params[:select_all] || params[:inverted]
      query_add = ' LIMIT '+limit.to_s+' OFFSET '+offset.to_s
    end

    base_query = 'SELECT products.id as id, products.name as name, products.status as status, products.updated_at as updated_at, product_skus.sku as sku, product_barcodes.barcode as barcode, product_cats.category as cat, product_inventory_warehouses.location_primary, product_inventory_warehouses.location_secondary, product_inventory_warehouses.location_tertiary, product_inventory_warehouses.available_inv as qty, inventory_warehouses.name as location_name, stores.name as store_type, products.store_id as store_id
      FROM products
        LEFT JOIN product_skus ON (products.id = product_skus.product_id)
        LEFT JOIN product_barcodes ON (product_barcodes.product_id = products.id)
            LEFT JOIN product_cats ON (products.id = product_cats.product_id)
            LEFT JOIN product_inventory_warehouses ON (product_inventory_warehouses.product_id = products.id)
            LEFT JOIN inventory_warehouses ON (product_inventory_warehouses.inventory_warehouse_id =  inventory_warehouses.id)
            LEFT JOIN stores ON (products.store_id = stores.id)
        WHERE
          (
            products.name like '+search+' OR product_barcodes.barcode like '+search+'
            OR product_skus.sku like '+search+' OR product_cats.category like '+search+'
            OR (
              product_inventory_warehouses.location_primary like '+search+'
              OR product_inventory_warehouses.location_secondary like '+search+'
              OR product_inventory_warehouses.location_tertiary like '+search+'
            )
          )
          '+kit_query+'
        GROUP BY products.id ORDER BY '+sort_key+' '+sort_order

    result_rows = Product.find_by_sql(base_query+query_add)


    if results_only
      result = result_rows
    else
      result = Hash.new
      result['products'] = result_rows
      if params[:select_all] || params[:inverted]
        result['count'] = result_rows.length
      else
        result['count'] = Product.count_by_sql('SELECT count(*) as count from('+base_query+') as tmp')
      end
    end


    return result
  end

  def do_getproducts
    sort_key = 'updated_at'
    sort_order = 'DESC'
    status_filter = 'active'
    limit = 10
    offset = 0
    query_add = ""
    kit_query = ""
    status_filter_text = ""
    is_kit = 0
    supported_sort_keys = ['updated_at', 'name', 'sku',
                           'status', 'barcode', 'location_primary','location_secondary','location_tertiary','location_name','cat','qty', 'store_type' ]
    supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
    supported_status_filters = ['all', 'active', 'inactive', 'new']
    supported_kit_params = ['0', '1', '-1']

    # Get passed in parameter variables if they are valid.
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0

    sort_key = params[:sort] if !params[:sort].nil? &&
        supported_sort_keys.include?(params[:sort].to_s)

    sort_order = params[:order] if !params[:order].nil? &&
        supported_order_keys.include?(params[:order].to_s)

    status_filter = params[:filter] if !params[:filter].nil? &&
        supported_status_filters.include?(params[:filter].to_s)

    is_kit = params[:is_kit].to_i if !params[:is_kit].nil?  &&
        supported_kit_params.include?(params[:is_kit].to_s)

    unless is_kit == -1
      kit_query = " WHERE products.is_kit="+is_kit.to_s
    end

    unless params[:select_all] || params[:inverted]
      query_add += " LIMIT "+limit.to_s+" OFFSET "+offset.to_s
    end

    #hack to bypass for now and enable client development
    # sort_key = 'name' if sort_key == 'sku'

    #todo status filters to be implemented

    unless status_filter == 'all'
      if is_kit == '-1'
        status_filter_text = " WHERE "
      else
        status_filter_text = " AND "
      end
      status_filter_text += " products.status='"+status_filter+"'"
    end

    if sort_key == 'sku'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_skus ON ("+
                                         "products.id = product_skus.product_id ) "+kit_query+
                                         status_filter_text+" ORDER BY product_skus.sku "+sort_order+query_add)
    elsif sort_key == 'store_type'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN stores ON ("+
                                         "products.store_id = stores.id ) "+kit_query+
                                         status_filter_text+" ORDER BY stores.name "+sort_order+query_add)
    elsif sort_key == 'barcode'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_barcodes ON ("+
                                         "products.id = product_barcodes.product_id ) "+kit_query+
                                         status_filter_text+" ORDER BY product_barcodes.barcode "+sort_order+query_add)
    elsif sort_key == 'location_primary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                            "products.id = product_inventory_warehouses.product_id ) "+ kit_query+
                                            status_filter_text+" ORDER BY product_inventory_warehouses.location_primary "+sort_order+query_add)
    elsif sort_key == 'location_secondary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                            "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                            status_filter_text+" ORDER BY product_inventory_warehouses.location_secondary "+sort_order+query_add)
    elsif sort_key == 'location_tertiary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                         "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                         status_filter_text+" ORDER BY product_inventory_warehouses.location_tertiary "+sort_order+query_add)
    elsif sort_key == 'location_name'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                            "products.id = product_inventory_warehouses.product_id )  LEFT JOIN inventory_warehouses ON("+
                                            "product_inventory_warehouses.inventory_warehouse_id = inventory_warehouses.id ) "+kit_query+
                                            status_filter_text+" ORDER BY inventory_warehouses.name "+sort_order+query_add)
    elsif sort_key == 'qty'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                            "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                            status_filter_text+" ORDER BY product_inventory_warehouses.available_inv "+sort_order+query_add)
    elsif sort_key == 'cat'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_cats ON ( "+
                                            "products.id = product_cats.product_id ) "+kit_query+
                                            status_filter_text+" ORDER BY product_cats.category "+sort_order+query_add)
    else
      products = Product.order(sort_key+" "+sort_order)
      unless is_kit == -1
        products = products.where(:is_kit=> is_kit.to_s)
      end
      unless status_filter == 'all'
          products = products.where(:status=>status_filter)
      end
      unless params[:select_all] || params[:inverted]
        products =  products.limit(limit).offset(offset)
      end
    end

    if products.length == 0
      products = Product.where(1)
      unless is_kit == -1
        products = products.where(:is_kit=> is_kit.to_s)
      end
      unless status_filter == 'all'
        products = products.where(:status=>status_filter)
      end
      unless params[:select_all] || params[:inverted]
        products =  products.limit(limit).offset(offset)
      end
    end
    return products
  end

  def make_products_list(products)
    @products_result = []
    products.each do |product|
      @product_hash = Hash.new
      @product_hash['id'] = product.id
      @product_hash['name'] = product.name
      @product_hash['status'] = product.status
      @product_hash['location_primary'] = ''
      @product_hash['location_secondary'] = ''
      @product_hash['location_tertiary'] = ''
      @product_hash['location_name'] = 'not_available'
      @product_hash['qty'] = 0
      @product_hash['barcode'] = ''
      @product_hash['sku'] = ''
      @product_hash['cat'] = ''
      @product_hash['image'] = ''

      @product_location = product.primary_warehouse
      unless @product_location.nil?
        @product_hash['location_primary'] = @product_location.location_primary
        @product_hash['location_secondary'] = @product_location.location_secondary
        @product_hash['location_tertiary'] = @product_location.location_tertiary
        @product_hash['qty'] = @product_location.available_inv
        if !@product_location.inventory_warehouse.nil?
          @product_hash['location_name'] = @product_location.inventory_warehouse.name
        end
      end
      @product_hash['barcode'] = product.primary_barcode
      @product_hash['sku'] = product.primary_sku
      @product_hash['cat'] = product.primary_category
      @product_hash['image'] = product.primary_image
      unless product.store.nil?
        @product_hash['store_name'] = product.store.name
      end

      @product_kit_skus = ProductKitSkus.where(:product_id=>product.id)
      if @product_kit_skus.length > 0
        @product_hash['productkitskus'] = []
        @product_kit_skus.each do |kitsku|
          @product_hash['productkitskus'].push(kitsku.id)
        end
      end

      @products_result.push(@product_hash)
    end
    return @products_result
  end

  def list_selected_products
    if params[:select_all] || params[:inverted]
      if !params[:search].nil? && params[:search] != ''
        result = do_search
      else
        result = do_getproducts
      end
    else
      result = params[:productArray]
    end

    result_rows = []
    if params[:inverted] && !params[:productArray].blank?
      not_in = []
      params[:productArray].each do |product|
        not_in.push(product['id'])
      end
      result.each do |single_product|
        unless not_in.include? single_product['id']
          result_rows.push(single_product)
        end
      end
    else
      result_rows = result
    end

    return result_rows
  end

  def get_products_count
    count = Hash.new
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    is_kit = params[:is_kit] if !params[:is_kit].nil?  &&
        supported_kit_params.include?(params[:is_kit])
    if is_kit == '-1'
      counts = Product.select('status,count(*) as count').where(:status=>['active','inactive','new']).group(:status)
    else
      counts = Product.select('status,count(*) as count').where(:is_kit=>is_kit.to_s,:status=>['active','inactive','new']).group(:status)
    end
    all = 0
    counts.each do |single|
      count[single.status] = single.count
      all += single.count
    end
    count['all'] = all
    count['search'] = 0
    count
  end
end
