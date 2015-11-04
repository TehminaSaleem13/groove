class ProductsController < ApplicationController
  before_filter :groovepacker_authorize!
  include ProductsHelper

  def import_products
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
          context = Groovepacker::Stores::Context.new(
            Groovepacker::Stores::Handlers::EbayHandler.new(@store))
          import_result = context.import_products
        elsif @store.store_type == 'Magento'
          context = Groovepacker::Stores::Context.new(
            Groovepacker::Stores::Handlers::MagentoHandler.new(@store))
          import_result = context.import_products
        elsif @store.store_type == 'Shipstation'
          context = Groovepacker::Stores::Context.new(
            Groovepacker::Stores::Handlers::ShipstationHandler.new(@store))
          import_result = context.import_products
        elsif @store.store_type == 'Shipstation API 2'
          context = Groovepacker::Stores::Context.new(
            Groovepacker::Stores::Handlers::ShipstationRestHandler.new(@store))
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
            response = mws.reports.get_report :report_id => params[:reportid]

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
      rescue Exception => e
        @result['status'] = false
        @result['messages'].push(e.message)
      end
    else
      @result['status'] = false
      @result['messages'].push('You can not import products')
    end
    if !import_result.nil?
      import_result[:messages].each do |message|
        @result['messages'].push(message)
      end
      @result['total_imported'] = import_result[:total_imported]
      @result['success_imported'] = import_result[:success_imported]
      @result['previous_imported'] = import_result[:previous_imported]
    end

    respond_to do |format|
      format.json { render json: @result }
    end

  end

  def import_images
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
        if @store.store_type == 'Shipstation'
          context = Groovepacker::Stores::Context.new(
            Groovepacker::Stores::Handlers::ShipstationHandler.new(@store))
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
    if !import_result.nil?
      import_result[:messages].each do |message|
        @result['messages'].push(message)
      end
      @result['total_imported'] = import_result[:total_imported]
      @result['success_imported'] = import_result[:success_imported]
      @result['previous_imported'] = import_result[:previous_imported]
    end

    respond_to do |format|
      format.json { render json: @result }
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
        products_api = mws.products.get_matching_products_for_id(:marketplace_id => @credential.marketplace_id,
                                                                 :id_type => 'SellerSKU', :id_list => ['T-TOOL'])
        require 'active_support/core_ext/hash/conversions'
        product_hash = Hash.from_xml(products_api.to_s)
        # product_hash = from_xml(products_api)
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

      response = mws.reports.request_report :report_type => '_GET_MERCHANT_LISTINGS_DATA_'
      @credential.productreport_id = response.report_request_info.report_request_id
      @credential.productgenerated_report_id = nil

      if @credential.save
        @result['status'] = true
        @result['requestedreport_id'] = @credential.productreport_id
      end

    end

    respond_to do |format|
      format.json { render json: @result }
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
      format.json { render json: @result }
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
  def index
    @result = Hash.new
    @result[:status] = true
    @products = do_getproducts(params)
    @result['products'] = make_products_list(@products)
    @result['products_count'] = get_products_count()
    respond_to do |format|
      format.json { render json: @result }
    end
  end

  def create
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('add_edit_products')
      product = Product.new
      product.name = "New Product"
      product.store_id = Store.where(:store_type => 'system').first.id
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
      format.json { render json: @result }
    end
  end

  def print_receiving_label
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    products = list_selected_products(params)
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
               :handlers => [:erb],
               :formats => [:html],
               :save_to_file => Rails.root.join('public', 'pdfs', "#{file_name}.pdf")

        render json: result
      }
    end
  end

  def generate_barcode
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    if current_user.can?('add_edit_products')
      @products = list_selected_products(params)
      unless @products.nil?
        @products.each do |product|
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

      @products = do_search(params, false)
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

  def scan_per_product
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      if !params[:setting].blank? && ['type_scan_enabled', 'click_scan_enabled'].include?(params[:setting])
        @products = list_selected_products(params)
        unless @products.nil?
          @products.each do |product|
            @product = Product.find(product['id'])
            @product[params[:setting]] = params[:status]
            unless @product.save
              @result['status'] &= false
              @result['messages'].push('There was a problem updating '+@product.name)
            end
          end
        end
      else
        @result['status'] = false
        @result['messages'].push('No action specified for updating')
      end

    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to edit this product')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def change_product_status
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      bulk_actions = Groovepacker::Products::BulkActions.new
      groove_bulk_actions = GrooveBulkActions.new
      groove_bulk_actions.identifier = 'product'
      groove_bulk_actions.activity = 'status_update'
      groove_bulk_actions.save

      bulk_actions.delay(:run_at => 1.seconds.from_now).status_update(Apartment::Tenant.current, params, groove_bulk_actions.id)

    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to edit product status')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def delete_product
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('delete_products')
      bulk_actions = Groovepacker::Products::BulkActions.new
      groove_bulk_actions = GrooveBulkActions.new
      groove_bulk_actions.identifier = 'product'
      groove_bulk_actions.activity = 'delete'
      groove_bulk_actions.save

      bulk_actions.delay(:run_at => 1.seconds.from_now).delete(Apartment::Tenant.current, params, groove_bulk_actions.id, current_user.username)
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to delete products')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def duplicate_product

    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      bulk_actions = Groovepacker::Products::BulkActions.new
      groove_bulk_actions = GrooveBulkActions.new
      groove_bulk_actions.identifier = 'product'
      groove_bulk_actions.activity = 'duplicate'
      groove_bulk_actions.save
      bulk_actions.delay(:run_at => 1.seconds.from_now).duplicate(Apartment::Tenant.current, params, groove_bulk_actions.id)
    else
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to duplicate products')
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def show
    @result = Hash.new
    @product = nil
    params[:id] = nil if params[:id]=="null"
    if !params[:id].nil?
      @product = Product.find_by_id(params[:id])
    else
      prod_barcodes = ProductBarcode.where(:barcode => params[:barcode])
      if prod_barcodes.length > 0
        @product = prod_barcodes.first.product
      end
    end
    if !@product.nil?
      @product.reload
      store_id = @product.store_id
      stores = Store.where(:id => store_id)
      if !stores.nil?
        @store = stores.first
      end
      general_setting = GeneralSetting.all.first
      scan_pack_setting = ScanPackSetting.all.first
      amazon_products = AmazonCredentials.where(:store_id => store_id)
      if !amazon_products.nil?
        @amazon_product = amazon_products.first
      end

      @result['product'] = Hash.new
      @result['product']['amazon_product'] = @amazon_product
      @result['product']['store'] = @store
      @result['product']['sync_option'] = @product.sync_option.attributes rescue nil
      @result['product']['access_restrictions'] = AccessRestriction.last rescue nil
      @result['product']['basicinfo'] = @product.attributes
      @result['product']['basicinfo']['weight_format'] = @product.get_show_weight_format
      @result['product']['basicinfo']['contains_intangible_string'] = @product.contains_intangible_string
      @result['product']['product_weight_format'] = GeneralSetting.get_product_weight_format
      @result['product']['weight'] = @product.get_weight
      @result['product']['shipping_weight'] = @product.get_shipping_weight
      @result['product']['skus'] = @product.product_skus.order("product_skus.order ASC")
      @result['product']['cats'] = @product.product_cats
      @result['product']['spl_instructions_4_packer'] = @product.spl_instructions_4_packer
      @result['product']['images'] = @product.base_product.product_images.order("product_images.order ASC")
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
          inv_wh_result['info']['quantity_on_hand'] = inv_wh.quantity_on_hand
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
          kit_sku['product_status'] = option_product.status
          if option_product.product_skus.length > 0
            kit_sku['sku'] = option_product.primary_sku
          end
          kit_sku['qty'] = kit.qty
          kit_sku['available_inv'] = 0
          kit_sku['qty_on_hand'] = 0
          option_product.product_inventory_warehousess.each do |inventory|
            kit_sku['available_inv'] += inventory.available_inv.to_i
            kit_sku['qty_on_hand'] += inventory.quantity_on_hand.to_i
          end
          kit_sku['packing_order'] = kit.packing_order
          kit_sku['option_product_id'] = option_product.id
          @result['product']['productkitskus'].push(kit_sku)
        end
        @result['product']['productkitskus'] =
          @result['product']['productkitskus'].sort_by { |hsh| hsh['packing_order'] }
        @result['product']['product_kit_activities'] = @product.product_kit_activities
        @result['product']['unacknowledged_kit_activities'] = @product.unacknowledged_kit_activities
      end

      if @product.product_skus.length > 0
        @result['product']['pendingorders'] = Order.where(:status => 'awaiting').where(:status => 'onhold').
          where(:sku => @product.product_skus.first.sku)
      else
        @result['product']['pendingorders'] = nil
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def add_product_to_kit
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @kit = Product.find_by_id(params[:id])

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
                unless @kit.save
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

  def remove_products_from_kit
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @kit = Product.find_by_id(params[:id])

      if @kit.is_kit
        if params[:kit_products].nil?
          @result['messages'].push("No sku sent in the request")
          @result['status'] &= false
        else
          params[:kit_products].reject! { |a| a=="" }
          params[:kit_products].each do |kit_product|
            product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(kit_product, @kit.id)

            if product_kit_sku.nil?
              @result['messages'].push("Product #{kit_product} not found in item")
              @result['status'] &= false
            else
              product_kit_sku.qty = 0
              product_kit_sku.save
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

  def update
    @result = Hash.new
    @product = Product.find(params[:basicinfo][:id]) unless params.nil? && params[:basicinfo].nil?
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
        # @product.status = params[:basicinfo][:status]
        @product.store_id = params[:basicinfo][:store_id]
        @product.store_product_id = params[:basicinfo][:store_product_id]
        @product.type_scan_enabled = params[:basicinfo][:type_scan_enabled]
        @product.click_scan_enabled = params[:basicinfo][:click_scan_enabled]
        @product.weight = @product.get_product_weight(params[:weight])
        @product.shipping_weight = @product.get_product_weight(params[:shipping_weight])
        @product.weight_format = get_weight_format(params[:basicinfo][:weight_format])
        @product.add_to_any_order = params[:basicinfo][:add_to_any_order]
        @product.product_receiving_instructions = params[:basicinfo][:product_receiving_instructions]
        @product.is_intangible = params[:basicinfo][:is_intangible]

        if !@product.save
          @result['status'] &= false
        end
        #Update product status and also update the containing kit and orders
        updatelist(@product, 'status', params[:basicinfo][:status]) unless params[:basicinfo][:status].nil?

        #Update product inventory warehouses
        #check if a product inventory warehouse is defined.
        product_inv_whs = ProductInventoryWarehouses.where(:product_id => @product.id)

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

                if general_setting.low_inventory_alert_email
                  product_inv_wh.product_inv_alert = wh["info"]["product_inv_alert"]
                  product_inv_wh.product_inv_alert_level = wh["info"]["product_inv_alert_level"]
                end
                product_inv_wh.quantity_on_hand= wh["info"]["quantity_on_hand"]
                # product_inv_wh.available_inv = wh["info"]["available_inv"]
                product_inv_wh.location_primary = wh["info"]["location_primary"]
                product_inv_wh.location_secondary = wh["info"]["location_secondary"]
                product_inv_wh.location_tertiary = wh["info"]["location_tertiary"]
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
        product_cats = ProductCat.where(:product_id => @product.id)

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

        product_skus = ProductSku.where(:product_id => @product.id)

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
        product_barcodes = ProductBarcode.where(:product_id => @product.id)
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
        product_images = ProductImage.where(:product_id => @product.id)

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

  def update_product_list
    @result = Hash.new
    @result['status'] = true

    if current_user.can?('add_edit_products')
      @product = Product.find_by_id(params[:id])
      if @product.nil?
        @result['status'] = false
        @result['error_msg'] ="Cannot find Product"
      else
        updatelist(@product, params[:var], params[:value])
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
  def set_alias
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products') && current_user.can?('delete_products')
      @product_orig = Product.find(params[:id])
      skus_len = @product_orig.product_skus.all.length
      barcodes_len = @product_orig.product_barcodes.all.length
      @product_aliases = Product.find_all_by_id(params[:product_alias_ids])
      if @product_aliases.length > 0
        @product_aliases.each do |product_alias|
          #all SKUs of the alias will be copied. dont use product_alias.product_skus
          @product_skus = ProductSku.where(:product_id => product_alias.id)
          @product_skus.each do |alias_sku|
            alias_sku.product_id = @product_orig.id
            alias_sku.order = skus_len
            skus_len+=1
            if !alias_sku.save
              result['status'] &= false
              result['messages'].push('Error saving Sku for sku id'+alias_sku.id.to_s)
            end
          end

          @product_barcodes = ProductBarcode.where(:product_id => product_alias.id)
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
          @order_items = OrderItem.where(:product_id => product_alias.id)
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

          #Ensure all inventory data is copied over
          #The code has been modified keeping in mind that we use only one warehouse per product as of now.
          orig_product_inv_wh = @product_orig.primary_warehouse
          aliased_inventory = product_alias.primary_warehouse
          if orig_product_inv_wh.nil?
            orig_product_inv_wh = ProductInventoryWarehouses.new
            orig_product_inv_wh.inventory_warehouse_id = aliased_inventory.inventory_warehouse_id
            orig_product_inv_wh.product_id = @product_orig.id
            orig_product_inv_wh.quantity_on_hand = aliased_inventory.quantity_on_hand
            orig_product_inv_wh.save
          end
          if orig_product_inv_wh.product.is_kit == 0
            #copy over the qoh of original as QOH of original should not change in aliasing
            orig_product_qoh = orig_product_inv_wh.quantity_on_hand
            orig_product_inv_wh.allocated_inv = orig_product_inv_wh.allocated_inv + aliased_inventory.allocated_inv
            
            orig_product_inv_wh.sold_inv = orig_product_inv_wh.sold_inv + aliased_inventory.sold_inv
            orig_product_inv_wh.quantity_on_hand = orig_product_qoh
            orig_product_inv_wh.save
          else
            orig_product_inv_wh.product.product_kit_skuss.each do |kit_sku|
              kit_option_product_wh = kit_sku.option_product.primary_warehouse
              unless kit_option_product_wh.nil?
                orig_kit_product_qoh = kit_option_product_wh.quantity_on_hand
                kit_option_product_wh.allocated_inv = kit_option_product_wh.allocated_inv + (kit_sku.qty * aliased_inventory.allocated_inv)
          
                kit_option_product_wh.sold_inv = kit_option_product_wh.sold_inv + (kit_sku.qty * aliased_inventory.sold_inv)
                kit_option_product_wh.quantity_on_hand = orig_kit_product_qoh
                kit_option_product_wh.save
              end 
            end
          end
          aliased_inventory.reload

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

  def add_image
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    if current_user.can?('add_edit_products')
      @product = Product.find(params[:id])
      if !@product.nil? && !params[:product_image].nil?
        @image = ProductImage.new

        #image_directory = "public/images"
        current_tenant = Apartment::Tenant.current
        file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')+@product.id.to_s+params[:product_image].original_filename
        GroovS3.create_image(current_tenant, file_name, params[:product_image].read, params[:product_image].content_type)
        #path = File.join(image_directory, file_name )
        #File.open(path, "wb") { |f| f.write(params[:product_image].read) }
        @image.image = ENV['S3_BASE_URL']+'/'+current_tenant+'/image/'+file_name
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
        product_inv_whs = ProductInventoryWarehouses.where(:product_id => product.id).
          where(:inventory_warehouse_id => params[:inv_wh_id])

        unless product_inv_whs.length == 1
          product_inv_wh = ProductInventoryWarehouses.new
          product_inv_wh.inventory_warehouse_id = params[:inv_wh_id]
          product.product_inventory_warehousess << product_inv_wh
          product.save
          product_inv_whs.reload
        end

        unless params[:inventory_count].blank?
          if params[:method] == 'recount'
            product_inv_whs.first.quantity_on_hand = params[:inventory_count]
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

  def generate_products_csv
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    if current_user.can? 'create_backups'
      products_list = list_selected_products(params)
      products = []
      products_list.each do |product|
        products.push(Product.find(product['id']))
      end
      result['filename'] = 'products-'+Time.now.to_s+'.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        ProductsHelper.products_csv(products, csv)
      end
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to create backup csv')
    end
    unless result['status']
      result['filename'] = 'error.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        csv << result['messages']
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_intangibleness
    result = Hash.new
    result['status'] = true
    if current_user.can?('add_edit_products')
      action_intangible = Groovepacker::Products::ActionIntangible.new

      scan_pack_setting = ScanPackSetting.all.first
      intangible_setting_enabled = scan_pack_setting.intangible_setting_enabled
      intangible_string = scan_pack_setting.intangible_string

      action_intangible.delay(:run_at => 1.seconds.from_now).update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
      # action_intangible.update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to edit product status')
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update_image
    result = Hash.new
    result['status'] = true
    begin
      image = ProductImage.find(params[:image][:id])
      image.added_to_receiving_instructions = params[:image][:added_to_receiving_instructions]
      image.image_note = params[:image][:image_note]
      image.save
    rescue
      result['status'] = false
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def sync_with
    result = Hash.new
    result['status'] = true
    begin
      product = Product.find_by_id(params[:id])
      sync_option = product.sync_option || product.build_sync_option
      sync_option.sync_with_bc = params["sync_with_bc"]
      sync_option.bc_product_id = params["bc_product_id"].to_i!=0 ? params["bc_product_id"] : nil
      sync_option.save
    rescue
      result['status'] = false
    end
    
    render json: result
  end

  private

  def get_weight_format(weight_format)
    unless weight_format.nil?
      return weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
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
      @product_hash['type_scan_enabled'] = product.type_scan_enabled
      @product_hash['click_scan_enabled'] = product.click_scan_enabled
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
        @product_hash['available_inv'] = @product_location.available_inv
        @product_hash['qty_on_hand'] = @product_location.quantity_on_hand
        if !@product_location.inventory_warehouse.nil?
          @product_hash['location_name'] = @product_location.inventory_warehouse.name
        end
      end
      @product_hash['barcode'] = product.primary_barcode
      @product_hash['sku'] = product.primary_sku
      @product_hash['cat'] = product.primary_category
      @product_hash['image'] = product.base_product.primary_image
      unless product.store.nil?
        @product_hash['store_name'] = product.store.name
      end

      @product_kit_skus = ProductKitSkus.where(:product_id => product.id)
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


  def get_products_count
    count = Hash.new
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    is_kit = params[:is_kit] if !params[:is_kit].nil? &&
      supported_kit_params.include?(params[:is_kit])
    if is_kit == '-1'
      counts = Product.select('status,count(*) as count').where(:status => ['active', 'inactive', 'new']).group(:status)
    else
      counts = Product.select('status,count(*) as count').where(:is_kit => is_kit.to_s, :status => ['active', 'inactive', 'new']).group(:status)
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
