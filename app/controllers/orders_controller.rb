class OrdersController < ApplicationController

  include OrdersHelper
  include ProductsHelper
  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orders }
    end
  end

  # Import orders from store based on store id
  def importorders
  @store = Store.find(params[:id])
  @result = Hash.new

  @result['status'] = true
  @result['messages'] = []
  @result['total_imported'] = 0
  @result['success_imported'] = 0
  @result['previous_imported'] = 0
  @result['activestoreindex'] = 0

  if !params[:activestoreindex].nil?
    @result['activestoreindex'] = params[:activestoreindex]
  end

 # begin
  #import if magento products
  if @store.store_type == 'Magento'
    @magento_credentials = MagentoCredentials.where(:store_id => @store.id)

    if @magento_credentials.length > 0
      client = Savon.client(wsdl: @magento_credentials.first.host+"/index.php/api/v2_soap/index/wsdl/1")

      if !client.nil?
                 # @result['client'] = client
        response = client.call(:login,  message: { apiUser: @magento_credentials.first.username,
          apikey: @magento_credentials.first.api_key })

          #@result['response'] = response
        if response.success?
          session =  response.body[:login_response][:login_return]

          @filters = Hash.new
          @filter = Hash.new
          item = Hash.new
          item['key'] = 'status'
          item['value'] = 'processing'
          @filter['item'] = item
          @filters['filter']  = @filter
          @filters_array = []
          @filters_array << @filters

          response = client.call(:sales_order_list, message: {sessionId: session, filters: @filters_array })

          if response.success?
           # @result['response'] = response.body
            @result['total_imported'] =  response.body[:sales_order_list_response][:result][:item].length

            response.body[:sales_order_list_response][:result][:item].each do |item|
              order_info = client.call(:sales_order_info,
                message:{sessionId: session, orderIncrementId: item[:increment_id]})

              order_info = order_info.body[:sales_order_info_response][:result]
              if Order.where(:increment_id=>item[:increment_id]).length == 0
                @order = Order.new
                @order.increment_id = item[:increment_id]
                @order.status = 'awaiting'
                @order.order_placed_time = item[:created_at]
                #@order.storename = item[:store_name]
                @order.store = @store
                line_items = order_info[:items]
                if line_items[:item].is_a?(Hash)
                    if line_items[:item][:product_type] == 'simple'
                      @order_item = OrderItem.new
                      @order_item.price = line_items[:item][:price]
                      @order_item.qty = line_items[:item][:qty_ordered]
                      @order_item.row_total= line_items[:item][:row_total]
                      @order_item.name = line_items[:item][:name]
                      @order_item.sku = line_items[:item][:sku]
                      if ProductSku.where(:sku=>@order_item.sku).length == 0
                        product_id = import_magento_product(client, session, @order_item.sku, @store.id,
                          @magento_credentials.first.import_images, @magento_credentials.first.import_products)
                      else
                        product_id = ProductSku.where(:sku=>@order_item.sku).first.product_id
                      end
                      @order_item.product_id = product_id
                      @order.order_items << @order_item
                    else
                      import_magento_product(client, session, line_items[:item][:sku], @store.id,
                          @magento_credentials.first.import_images, @magento_credentials.first.import_products)
                    end
                else
                  line_items[:item].each do |line_item|
                    if line_item[:product_type] == 'simple'
                      @order_item = OrderItem.new
                      @order_item.price = line_item[:price]
                      @order_item.qty = line_item[:qty_ordered]
                      @order_item.row_total= line_item[:row_total]
                      @order_item.name = line_item[:name]
                      @order_item.sku = line_item[:sku]

                      if ProductSku.where(:sku=>@order_item.sku).length == 0
                        product_id = import_magento_product(client, session, @order_item.sku, @store.id,
                          @magento_credentials.first.import_images, @magento_credentials.first.import_products)
                      else
                        product_id = ProductSku.where(:sku=>@order_item.sku).first.product_id
                      end
                      @order_item.product_id = product_id
                      @order.order_items << @order_item
                    else
                      import_magento_product(client, session, line_item[:sku], @store.id,
                          @magento_credentials.first.import_images, @magento_credentials.first.import_products)
                    end
                  end
                end

              #if product does not exist import product using product.info
              @order.address_1  = order_info[:shipping_address][:street]
              @order.city = order_info[:shipping_address][:city]
              @order.country = order_info[:shipping_address][:country_id]
              @order.postcode = order_info[:shipping_address][:postcode]
              @order.email = item[:customer_email]
              @order.lastname = order_info[:shipping_address][:lastname]
              @order.firstname = order_info[:shipping_address][:firstname]
              @order.state = order_info[:shipping_address][:region]
              if @order.save
                  if !@order.addnewitems
                    @result['status'] &= false
                    @result['messages'].push('Problem adding new items')
                  end
                  @order.addactivity("Order Import", @store.name+" Import")
                  @order.order_items.each do |item|
                    @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
                  end
                  @order.set_order_status
                  @result['success_imported'] = @result['success_imported'] + 1
                end
              else
                @result['previous_imported'] = @result['previous_imported'] + 1
              end
            end
          else
            @result['status'] = false
            @result['messages'].push('Problem retrieving products list')
          end
        else
          @result['status'] = false
          @result['messages'].push('Problem connecting to Magento API. Authentication failed')
        end
      else
        @result['status'] = false
        @result['messages'].push('Problem connecting to Magento API. Check the hostname of the server')
      end
    else
      @result['status'] = false
      @result['messages'].push('No Store found!')
    end
  elsif @store.store_type == 'Ebay'
    #do ebay connect.
    @ebay_credentials = EbayCredentials.where(:store_id => @store.id)

    if @ebay_credentials.length > 0
      @credential = @ebay_credentials.first
      require 'eBayAPI'
      if ENV['EBAY_SANDBOX_MODE'] == 'YES'
        sandbox = true
      else
        sandbox = false
      end
      @eBay = EBay::API.new(@credential.auth_token,
        ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
        ENV['EBAY_CERT_ID'], :sandbox=>sandbox)

      seller_list =@eBay.GetOrders(:orderRole=> 'Seller', :orderStatus=>'Completed',
        :createTimeFrom=> (Date.today - 3.months).to_datetime,
         :createTimeTo =>(Date.today + 1.day).to_datetime)
      if (seller_list.orderArray != nil)
        @result['total_imported']  = seller_list.orderArray.size
      #@result['seller_list'] = seller_list.transactionArray
      #@result['app_id'] = @credential
      @ordercnt = 0
      seller_list.orderArray.each do |order|
        if order.checkoutStatus.status == 'Complete'
          @ordercnt = @ordercnt + 1
        end
      end
      seller_list.orderArray.each do |order|
        if Order.where(:increment_id=>order.shippingDetails.sellingManagerSalesRecordNumber).length == 0 &&
            order.checkoutStatus.status == 'Complete'
          @order = Order.new
          @order.status = 'awaiting'
          @order.store = @store
          @order.increment_id = order.shippingDetails.sellingManagerSalesRecordNumber
          @order.order_placed_time = order.createdTime

          order.transactionArray.each do |transaction|
            @order_item = OrderItem.new
            @order_item.price = transaction.transactionPrice
            @order_item.qty = transaction.quantityPurchased
            @order_item.row_total= transaction.amountPaid
            if !transaction.item.sKU.nil?
              @order_item.sku = transaction.item.sKU
            end
            @item = @eBay.getItem(:ItemID => transaction.item.itemID).item
            @order_item.name = @item.title

          if ProductSku.where(:sku=> transaction.item.sKU).length == 0
            @productdb = Product.new
            @productdb.name = @item.title
            @productdb.store_product_id = @item.itemID
            @productdb.product_type = 'not_used'
            @productdb.status = 'inactive'
            @productdb.store = @store

            #add productdb sku
            @productdbsku = ProductSku.new
            if  @item.sKU.nil?
              @productdbsku.sku = "not_available"
            else
              @productdbsku.sku = @item.sKU
            end
            #@item.productListingType.uPC
            @productdbsku.purpose = 'primary'

            #publish the sku to the product record
            @productdb.product_skus << @productdbsku

            if @credential.import_images
              if !@item.pictureDetails.nil?
                if !@item.pictureDetails.pictureURL.nil? &&
                  @item.pictureDetails.pictureURL.length > 0
                  @productimage = ProductImage.new
                  @productimage.image = "http://i.ebayimg.com" +
                    @item.pictureDetails.pictureURL.first.request_uri()
                  @productdb.product_images << @productimage

                end
              end
            end

            if @credential.import_products
              if !@item.primaryCategory.nil?
                @product_cat = ProductCat.new
                @product_cat.category = @item.primaryCategory.categoryName
                @productdb.product_cats << @product_cat
              end

              if !@item.secondaryCategory.nil?
                @product_cat = ProductCat.new
                @product_cat.category = @item.secondaryCategory.categoryName
                @productdb.product_cats << @product_cat
              end
            end

            @productdb.save
            @productdb.set_product_status
            @order_item.product_id = @productdb.id
          else
            @order_item.product_id  = ProductSku.where(:sku=> transaction.item.sKU).first.product_id
          end

          @order.order_items << @order_item
          end

          @order.address_1  = order.shippingAddress.street1
          @order.city = order.shippingAddress.cityName
          #@shipping.region = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
          @order.state = order.shippingAddress.stateOrProvince
          @order.country = order.shippingAddress.country
          @order.postcode = order.shippingAddress.postalCode

          #split name separated by a space
          split_name = order.shippingAddress.name.split(' ')
          @order.lastname = split_name.pop
          @order.firstname = split_name.join(' ')
          #@order.order_shipping = @shipping
          if @order.save
            @order.addactivity("Order Import", @store.name+" Import")
            @order.order_items.each do |item|
              @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
            end

            @order.set_order_status
            @result['success_imported'] = @result['success_imported'] + 1
          end
        else
          @result['previous_imported'] = @result['previous_imported'] + 1
        end
      end
    end

    end
  elsif @store.store_type == 'Amazon'
    @amazon_credentials = AmazonCredentials.where(:store_id => @store.id)

    if @amazon_credentials.length > 0
      @credential = @amazon_credentials.first
      mws = MWS.new(:aws_access_key_id => ENV['AMAZON_MWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['AMAZON_MWS_SECRET_ACCESS_KEY'],
        :seller_id => @credential.merchant_id,
        :marketplace_id => @credential.marketplace_id)

      #@result['aws-response'] = mws.reports.request_report :report_type=>'_GET_MERCHANT_LISTINGS_DATA_'
      #@result['aws-rewuest_status'] = mws.reports.get_report_request_list
      response = mws.orders.list_orders :last_updated_after => 2.months.ago, :order_status => ['Unshipped', 'PartiallyShipped']
            #@result['report_id'] = response.body
      @orders = []

      if !response.orders.kind_of?(Array)
        @orders.push(response.orders)
      else
        @orders = response.orders
      end

      if !@orders.nil?
        @result['total_imported'] = @orders.length
        @orders.each do |order|
        if Order.where(:increment_id=>order.amazon_order_id).length == 0
          @order = Order.new
          @order.status = 'awaiting'
          @order.increment_id = order.amazon_order_id
          #@order.storename = @store.name
          @order.order_placed_time = order.purchase_date

          @order.store = @store

          order_items  = mws.orders.list_order_items :amazon_order_id => order.amazon_order_id
          @result['orderitem'] = order_items

          order_items.order_items.each do |item|
            @order_item = OrderItem.new
            @order_item.price = item.item_price.amount
            @order_item.qty = item.quantity_ordered
            @order_item.row_total= item.item_price.amount.to_i * item.quantity_ordered.to_i
            @order_item.sku = item.seller_sku
            if ProductSku.where(:sku=>item.seller_sku).length == 0
              #create and import product
              product = Product.new
              product.name = 'New imported item'
              product.store_product_id = 0
              product.store = @store

              sku = ProductSku.new
              sku.sku = item.seller_sku

              product.product_skus << sku
              product.save
              import_amazon_product_details(@store.id, item.seller_sku, product.id)
            else
              @order_item.product = ProductSku.where(:sku=>item.seller_sku).first.product
            end
            @order_item.name = item.title
          end

          @order.order_items << @order_item

              @order.address_1  = order.shipping_address.address_line1
              @order.city = order.shipping_address.city
              @order.country = order.shipping_address.country_code
              @order.postcode = order.shipping_address.postal_code
              @order.state = order.shipping_address.state_or_region
              @order.email = order.buyer_email
              @order.lastname = order.shipping_address.name
              split_name = order.shipping_address.name.split(' ')
              @order.lastname = split_name.pop
              @order.firstname = split_name.join(' ')

          if @order.save
            if !@order.addnewitems
              @result['status'] &= false
              @result['messages'].push('Problem adding new items')
            end
            @order.addactivity("Order Import", @store.name+" Import")
            @order.order_items.each do |item|
              @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
            end
            @order.set_order_status
            @result['success_imported'] = @result['success_imported'] + 1
          end
        else
          @result['previous_imported'] = @result['previous_imported'] + 1
        end
        end

      end
      @result['response'] = response
    end
  end
  # rescue Exception => e
  #   @result['status'] = false
  #   @result['messages'].push(e.message)
  #   puts e.backtrace
  # end
    respond_to do |format|
      format.json { render json: @result}
    end
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    @order = Order.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @order }
    end
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(params[:order])

    respond_to do |format|
      if @order.save
        format.html { redirect_to @order, notice: 'Order was successfully created.' }
        format.json { render json: @order, status: :created, location: @order }
      else
        format.html { render action: "new" }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /orders/1
  # PUT /orders/1.json
  def update
    @order = Order.find(params[:id])
    @result = Hash.new
    @result['status']= true
    unless @order.update_attributes(params[:order])
      @result['status'] &= false
      @result['messages'] = @order.errors.full_messages
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end


  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order = Order.find(params[:id])
    @order.destroy

    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end

  # Get list of orders based on limit and offset. It is by default sorted by updated_at field
  # If sort parameter is passed in then the corresponding sort filter will be used to sort the list
  # The expected parameters in params[:sort] are
  # . The API supports to provide order of sorting namely ascending or descending. The parameter can be
  # passed in using params[:order] = 'ASC' or params[:order] ='DESC' [Note: Caps letters] By default, if no order is mentioned,
  # then the API considers order to be descending.The API also supports a product status filter.
  # The filter expects one of the following parameters in params[:filter] 'all', 'active', 'inactive', 'new'.
  # If no filter is passed, then the API will default to 'active'
  def getorders
    @result = Hash.new
    @result['status'] = true

    @orders = do_getorders

    @result['orders'] = make_orders_list(@orders)

    respond_to do |format|
          format.json { render json: @result}
      end
  end

  def duplicateorder

    @result = Hash.new
    @result['status'] = true
    @orders = list_selected_orders
    unless @orders.nil?
      @orders.each do|order|

        @order = Order.find(order["id"])

        @neworder = @order.dup
        index = 0
        @order.increment_id = @order.increment_id+"(duplicate"+index.to_s+")"
        @orderlist = Order.where(:increment_id=>@order.increment_id)
        begin
          index = index + 1
          @neworder.increment_id = @order.increment_id+"(duplicate"+index.to_s+")"
          @orderslist = Order.where(:increment_id=>@neworder.increment_id)
        end while(!@orderslist.nil? && @orderslist.length > 0)

        if !@neworder.save(:validate => false)
          @result['status'] = false
          @result['messages'] = @neworder.errors.full_messages
        end
      end
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteorder
    @result = Hash.new
    @result['status'] = true
    @orders = list_selected_orders
    unless @orders.nil?
      @orders.each do|order|
        @order = Order.find(order["id"])
        if @order.destroy
          @result['status'] &= true
        else
          @result['status'] &= false
          @result['messages'] = @order.errors.full_messages
        end
      end
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

      @orders = do_search

      @result['orders'] = make_orders_list(@orders)
    else
      @result['status'] = false
      @result['message'] = 'Improper search string'
    end


    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def changeorderstatus
    @result = Hash.new
    @result['status'] = true
    @orders = list_selected_orders
    unless @orders.nil?
      @orders.each do|order|
        @order = Order.find(order["id"])
        @order.status = params[:status]
        unless @order.save
          @result['status'] = false
          @result['messages'] = @order.errors.full_messages
        end
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def getdetails
    @result = Hash.new
    @order = Order.find_by_id(params[:id])
    @result['status'] = true

    if !@order.nil?
      @result['order'] = Hash.new
      @result['order']['basicinfo'] = @order

      #Retrieve order items
      @result['order']['items'] = []
      @order.order_items.each do |orderitem|
        @orderitem = Hash.new
        @orderitem['iteminfo'] = orderitem
        product = Product.find_by_id(orderitem.product_id)
        if product.nil?
          @orderitem['productinfo'] = nil
          @orderitem['productimages'] = nil
        else
          @orderitem['productinfo'] = product
          @orderitem['qty_on_hand'] = 0
          product.product_inventory_warehousess.each do |inventory|
            @orderitem['qty_on_hand'] +=  inventory.qty.to_i
          end
          if product.product_inventory_warehousess.length > 0
            @orderitem["location"] = product.product_inventory_warehousess.first.name
          end
          if product.product_skus.length > 0
            @orderitem['sku'] = product.product_skus.first.sku
          end
          @orderitem['productimages'] = product.product_images

        end
        @result['order']['items'].push(@orderitem)
      end
      @result['order']['storeinfo'] = @order.store

      #setting user permissions for add and remove items permitted
      @result['order']['add_items_permitted'] = current_user.add_order_items
      @result['order']['remove_items_permitted'] = current_user.remove_order_items
      @result['order']['activities'] = @order.order_activities
      @result['order']['exception'] = @order.order_exceptions
      @result['order']['exception']['assoc'] =
        User.find(@order.order_exceptions.user_id) if !@order.order_exceptions.nil? && @order.order_exceptions.user_id !=0

      @result['order']['users'] = User.all

      #add a user with name of nobody to display in the list
      dummy_user = User.new
      dummy_user.name = 'Nobody'
      dummy_user.id = 0
      @result['order']['users'].unshift(dummy_user)

      if !@order.packing_user_id.nil?
        @result['order']['users'].each do |user|
          if user.id == @order.packing_user_id
            user.name = user.name + ' (Packing User)'
          end
        end
      end

      @result['order']['tags'] = @order.order_tags
    else
      @result['status'] = false
      @result['error_message'] = "Could not find order"
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def additem
    @result = Hash.new
  end

  def removeitem
  end

  def recordexception
    @result = Hash.new
    @result['status'] = true
    username = current_user.name
    @result['messages'] = []

    @order = Order.find(params[:id])

    if !params[:reason].nil?
      if @order.order_exceptions.nil?
        @exception = OrderExceptions.new
        @exception.order_id = @order.id
      else
        @exception = @order.order_exceptions
      end

      @exception.reason = params[:reason]
      @exception.description = params[:description]
      if !params[:assoc].nil? && !params[:assoc][:id] != 0
        @exception.user_id = params[:assoc][:id]
        username = params[:assoc][:name]
      end

      if @exception.save
        @order.addactivity("Order Exception Associated with "+username+" - Recorded", current_user.name)
      else
        @result['status'] &= false
        @result['messages'].push('Could not save order with exception')
      end
    else
      @result['status'] &= false
      @result['messages'].push('Cannot record exception without a reason')
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def clearexception
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    @order = Order.find(params[:id])
    if @order.order_exceptions.nil?
      @result['status'] &= false
      @result['messages'].push('Order does not have exception to clear')
    else
      if @order.order_exceptions.destroy
        @order.addactivity("Order Exception Cleared", current_user.name)
      else
        @result['status'] &= false
        @result['messages'].push('Error clearing exceptions')
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def additemtoorder
    @result = Hash.new
    @result['status'] = true
    qty = 1
    qty = params[:qty] if !params[:qty].nil? && params[:qty].to_i > -1
    @order = Order.find(params[:id])
    @products = Product.find(params[:productids])
    if @products.nil?
      @result['status'] &= false
      @result['messages'].push("Could not find any Item")
    else
      @products.each do |product|
        @orderitem = OrderItem.new
        @orderitem.name = product.name
        @orderitem.price = params[:price]
        @orderitem.qty = qty.to_i
        @orderitem.row_total = params[:price].to_f * params[:qty].to_f
        @orderitem.product_id = product.id
        @order.order_items << @orderitem
        if @orderitem.save && product.is_kit == 1
          kit_skus = ProductKitSkus.where(:product_id => @orderitem.product_id)
          kit_skus.each do |kit_sku|
            kit_sku.add_product_in_order_items
          end
        end
      end
      if !@order.save
        @result['status'] &= false
        @result['messages'].push("Adding item to order failed")
      else
        @order.update_order_status
      end
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def updateiteminorder
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    @orderitem = OrderItem.find_by_id(params[:orderitem])
    if @orderitem.nil?
      @result['status'] &= false
      @result['messages'].push("Could not find order item")
    else
      @orderitem.qty = params[:qty]

      unless @orderitem.save
        @result['status'] &= false
        @result['messages'].push("Could not update order item")
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def removeitemfromorder
    @result = Hash.new
    @result['status'] = true
    @result['messages'] =[]

    @orderitem = OrderItem.find(params[:orderitem])

    if !@orderitem.nil?
      @orderitem.each do |item|
        unless item.remove_order_item_kit_products && item.destroy
          @result['status'] &= false
          @result['messages'].push("Removed items from order failed")
        else
          item.order.update_order_status
        end
      end
    else
      @result['status'] &= false
      @result['messages'].push("Could not find order item")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def rollback
    @result = Hash.new
    @result['status'] = true
    @result['messages'] =[]
    if params[:single].nil?
      @result['status'] &= false
      @result['messages'].push("Order can not be nil")
    else
      order = Order.find(params[:single]['basicinfo']['id'])
      if order.nil?
        @result['status'] &= false
        @result['messages'].push("Wrong order id")
      else
        #Items
        items = OrderItem.where(:order_id => order.id)
        items.each do |current_item|
          found_item = false
          unless params[:single]['items'].blank?
            params[:single]['items'].each do |single_item|
              if current_item.id == single_item['iteminfo']['id']
                found_item = true
              end
            end
          end

          unless found_item
            current_item.destroy
          end
        end
        unless params[:single]['items'].blank?
          params[:single]['items'].each do |current_item|
            single_item = OrderItem.find_or_create_by_order_id_and_product_id( order.id, current_item['iteminfo']['product_id'])
              current_item['iteminfo'].each do |value|
                unless ["id","created_at","updated_at","order_id","product_id"].include?(value[0])
                  single_item[value[0]] = value[1]
                end
              end
              single_item.save!

            current_product = Product.find(current_item['iteminfo']['product_id'])
            updatelist(current_product,'name',current_item['productinfo']['name'])
            updatelist(current_product,'is_skippable',current_item['productinfo']['is_skippable'])
            updatelist(current_product,'qty',current_item['qty_on_hand'])
            updatelist(current_product,'location_name',current_item['location'])
            updatelist(current_product,'sku',current_item['sku'])

          end
        end

        #activity
        #As activities only get added, no updating or adding required
        activities = OrderActivity.where(:order_id => params[:single]['basicinfo']['id'])
        activities.each do |current_activity|
          found_activity = false
          params[:single]['activities'].each do |single_item|
            if current_activity.id == single_item['id']
              found_activity = true
            end
          end
          unless found_activity
            current_activity.destroy
          end
        end

        #exception
        if params[:single]['exception'].nil?
          unless order.order_exceptions.nil?
            order.order_exceptions.destroy
          end
        else
          exception = OrderExceptions.find_or_create_by_order_id(order.id)
          params[:single]['exception'].each do |value|
            unless ["id","created_at","updated_at","order_id","assoc"].include?(value[0])
              exception[value[0]] = value[1]
            end
          end
          exception.save!
        end

      end
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def updateorderlist
    @result = Hash.new
    @result['status'] = true
    @order = Order.find_by_id(params[:id])
    if @order.nil?
      @result['status'] = false
      @result['error_msg'] = "Cannot find Order"
    else
      accepted_data = {
          "ordernum" => "increment_id",
          "order_date" => "order_placed_time",
          "recipient" => 1,
          "notes" => "notes_internal",
          "notes_from_packer" => "notes_fromPacker",
          "status" => "status",
          "email" => "email",
          "tracking_num" => "tracking_num",
          "city"=>"city",
          "state"=>"state",
          "postcode"=>"postcode",
          "country"=>"country"
      }
      if accepted_data.has_key?(params[:var])
        if params[:var] == "recipient"
          arr = params[:value].blank? ? [] : params[:value].split(" ")
          @order.lastname = arr.pop()
          @order.firstname = arr.join(" ")
        else
          key = accepted_data[params[:var]]
          @order[key] = params[:value]
        end
        unless @order.save
          @result['status'] &= false
          @result['error_msg'] = "Could not save order info"
        end
      else
        @result['status'] &= false
        @result['error_msg'] = "Unknown field"
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def update_order_status
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    if !params[:order_id].nil?
    #check if order status is On Hold
    @order = Order.find(params[:order_id])
    if !@order.nil?
      @order.update_order_status
    else
      @result['status'] &= false
      @result['error_messages'].push("Could not find order with id:"+params[:order_id])
    end

    #check if current user edit confirmation code is same as that entered
    else
    @result['status'] &= false
    @result['error_messages'].push("Please specify order id to update order status")
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  private

  def do_search
    limit = 10
    offset = 0
    # Get passed in parameter variables if they are valid.
    limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0
    search = params[:search]
    query = "SELECT * from orders WHERE
                      increment_id like '%"+search+"%' OR email like '%"+search+"%' OR CONCAT(IFNULL(firstname,''),' ',IFNULL(lastname,'')) like '%"+search+"%' OR postcode like '%"+search+"%'"
    unless params[:select_all]
      query = query +" LIMIT #{limit} OFFSET #{offset}"
    end
    #todo: include sku and storename in search as well in future.
    return  Order.find_by_sql(query)
  end

  def do_getorders
    sort_key = 'updated_at'
    sort_order = 'DESC'
    status_filter = 'awaiting'
    limit = 10
    offset = 0
    query_add = ""
    status_filter_text = ""
    supported_sort_keys = ['updated_at', 'store_name', 'notes',
                           'ordernum', 'order_date', 'itemslength', 'recipient', 'status','email','tracking_num','city','state','postcode','country' ]
    supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
    supported_status_filters = ['all', 'awaiting', 'onhold', 'cancelled', 'scanned', 'serviceissue']


    # Get passed in parameter variables if they are valid.
    limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0

    unless params[:select_all]
      query_add = " LIMIT "+limit+" OFFSET "+offset
    end

    sort_key = params[:sort] if !params[:sort].nil? &&
        supported_sort_keys.include?(params[:sort])

    sort_order = params[:order] if !params[:order].nil? &&
        supported_order_keys.include?(params[:order])

    status_filter = params[:filter] if !params[:filter].nil? &&
        supported_status_filters.include?(params[:filter])


    #overrides

    if sort_key == 'ordernum'
      sort_key = 'increment_id'
    end

    if sort_key == 'order_date'
      sort_key = 'order_placed_time'
    end

    if sort_key == 'notes'
      sort_key = 'notes_toPacker'
    end

    if sort_key == 'recipient'
      sort_key = 'firstname '+sort_order+', lastname'
    end

    #hack to bypass for now and enable client development
    #sort_key = 'updated_at' if sort_key == 'sku'

    unless status_filter == 'all'
      status_filter_text = " WHERE orders.status='"+status_filter+"'"
    end
    #todo status filters to be implemented
    if sort_key == 'store_name'
      orders = Order.find_by_sql("SELECT orders.* FROM orders LEFT JOIN stores ON orders.store_id = stores.id "+status_filter_text+
                                     " ORDER BY stores.name "+ sort_order+query_add)
    elsif sort_key == 'itemslength'
      orders = Order.find_by_sql("SELECT orders.*, sum(order_items.qty) AS count FROM orders LEFT JOIN order_items"+
                                      " ON (order_items.order_id = orders.id) "+status_filter_text+" GROUP BY orders.id "+
                                      "ORDER BY count "+sort_order+query_add)
    else
      orders = Order.order(sort_key+" "+sort_order)
      unless status_filter == "all"
        orders = orders.where(:status=>status_filter)
      end
      unless params[:select_all]
        orders = orders.limit(limit).offset(offset)
      end
    end
    return orders
  end

  def make_orders_list(orders)
    @orders_result = []

    orders.each do |order|
      @order_hash = Hash.new
      @order_hash['id'] = order.id
      if !order.store_id.nil?
        @order_hash['store_name'] = Store.find(order.store_id).name
      else
        @order_hash['store_name'] = ''
      end
      @order_hash['notes'] = order.notes_internal
      @order_hash['ordernum'] = order.increment_id
      @order_hash['order_date'] = order.order_placed_time
      @order_hash['itemslength'] = order.get_items_count
      @order_hash['status'] = order.status
      @order_hash['recipient'] = "#{order.firstname} #{order.lastname}"
      @order_hash['email'] = order.email
      @order_hash['tracking_num'] = order.tracking_num
      @order_hash['city'] = order.city
      @order_hash['state'] = order.state
      @order_hash['postcode'] =order.postcode
      @order_hash['country'] = order.country
      @order_hash['tags'] = order.order_tags
      @orders_result.push(@order_hash)
    end
    return @orders_result
  end

  def list_selected_orders
    if params[:select_all]
      if !params[:search].nil? && params[:search] != ''
        return do_search
      else
        return do_getorders
      end
    else
      return params[:orderArray]
    end
  end

end
