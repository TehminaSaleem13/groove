class OrdersController < ApplicationController
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

begin
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
              if Order.where(:increment_id=>item[:order_id]).length == 0
                @order = Order.new
                @order.increment_id = item[:order_id]
                @order.status = 'Awaiting'
                #@order.storename = item[:store_name]
                @order.store = @store
                line_items = order_info[:items]
                if line_items[:item].is_a?(Hash)
                    @order_item = OrderItem.new
                    @order_item.price = line_items[:item][:price]
                    @order_item.qty = line_items[:item][:qty_ordered]
                    @order_item.row_total= line_items[:item][:row_total]
                    @order_item.name = line_items[:item][:name]
                    @order_item.sku = line_items[:item][:sku] 
                    @order.order_items << @order_item
                else
                  line_items[:item].each do |line_item|
                    @order_item = OrderItem.new
                    @order_item.price = line_item[:price]
                    @order_item.qty = line_item[:qty_ordered]
                    @order_item.row_total= line_item[:row_total]
                    @order_item.name = line_item[:name]
                    @order_item.sku = line_item[:sku]
                    @order.order_items << @order_item
                  end
                end
              
              @order.address_1  = order_info[:shipping_address][:street]
              @order.city = order_info[:shipping_address][:city]
              @order.country = order_info[:shipping_address][:country_id]
              @order.postcode = order_info[:shipping_address][:postcode]
              @order.email = item[:customer_email]
              @order.lastname = order_info[:shipping_address][:lastname]
              @order.firstname = order_info[:shipping_address][:firstname]
                # @shipping = OrderShipping.new

                # @shipping.streetaddress1 =  order_info[:shipping_address][:street]
                # @shipping.city = order_info[:shipping_address][:city]
                # @shipping.region = order_info[:shipping_address][:region]
                # @shipping.country = order_info[:shipping_address][:country_id]
                # @shipping.postcode = order_info[:shipping_address][:postcode]
                # @shipping.email = item[:customer_email]
                # @shipping.lastname = order_info[:shipping_address][:lastname]
                # @shipping.firstname = order_info[:shipping_address][:firstname]

                # @order.order_shipping = @shipping
                if @order.save
                  if !@order.addnewitems
                    @result['status'] &= false
                    @result['messages'].push('Problem adding new items')  
                  end
                  @order.addactivity("Order Import", @store.name+" Import")
                  @order.order_items.each do |item|
                    @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
                  end
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

      seller_list =@eBay.GetSellerTransactions(:orderRole=> 'Seller', :orderStatus=>'Paid', 
        :createTimeFrom=> (Date.today - 3.months).to_datetime,
         :createTimeTo =>(Date.today + 1.day).to_datetime)
      if (seller_list.transactionArray != nil)
        @result['total_imported']  = seller_list.transactionArray.size
      #@result['seller_list'] = seller_list.transactionArray
      #@result['app_id'] = @credential
      seller_list.transactionArray.each do |transaction|
        if Order.where(:increment_id=>transaction.transactionID).length == 0
          @order = Order.new
          @order.status = 'Awaiting'
          @order.store = @store
          @order.increment_id = transaction.transactionID

          @order_item = OrderItem.new
          @order_item.price = transaction.item.sellingStatus.currentPrice
          @order_item.qty = transaction.quantityPurchased
          @order_item.row_total= transaction.transactionPrice
          @order_item.sku = transaction.item.itemID
          if !transaction.item.title.nil?
            @order_item.name = transaction.item.title
          else
            @order_item.name = ""
          end

          @order.order_items << @order_item
# address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname, 
#           @order.address_1 = 

          #@shipping = OrderShipping.new


          @order.address_1  = transaction.buyer.buyerInfo.shippingAddress.street1
          @order.city = transaction.buyer.buyerInfo.shippingAddress.cityName
          #@shipping.region = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
          @order.country = transaction.buyer.buyerInfo.shippingAddress.country
          @order.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
          @order.lastname = transaction.buyer.buyerInfo.shippingAddress.name

          #@order.order_shipping = @shipping
          if @order.save
            if !@order.addnewitems
              @result['status'] &= false
              @result['messages'].push('Problem adding new items')  
            end
            @order.addactivity("Order Import", @store.name+" Import")
            @order.order_items.each do |item|
              @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
            end
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
      
      @orders = response.orders
      if !@orders.nil?
        @result['total_imported'] = @orders.length
        @orders.each do |order|
        if Order.where(:increment_id=>order.amazon_order_id).length == 0
          @order = Order.new
          @order.status = 'Awaiting'
          @order.increment_id = order.amazon_order_id
          #@order.storename = @store.name
          @order.store = @store
          
          order_items  = mws.orders.list_order_items :amazon_order_id => order.amazon_order_id
          @result['orderitem'] = order_items

          order_items.order_items.each do |item|
            @order_item = OrderItem.new
            @order_item.price = item.item_price.amount
            @order_item.qty = item.quantity_ordered
            @order_item.row_total= item.item_price.amount.to_i * item.quantity_ordered.to_i
            @order_item.sku = item.seller_sku
            @order_item.name = item.title
          end

          @order.order_items << @order_item

              @order.address_1  = order.shipping_address.address_line1
              @order.city = order.shipping_address.city
              @order.country = order.shipping_address.country
              @order.postcode = order.shipping_address.postal_code
              @order.email = order.buyer_email
              @order.lastname = order.shipping_address.name

          if @order.save
            if !@order.addnewitems
              @result['status'] &= false
              @result['messages'].push('Problem adding new items')  
            end
            @order.addactivity("Order Import", @store.name+" Import")
            @order.order_items.each do |item|
              @order.addactivity("Item with SKU: "+item.sku+" Added", @store.name+" Import")
            end
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

  end
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

    respond_to do |format|
      if @order.update_attributes(params[:order])
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
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
    @result[:status] = true
    sort_key = 'updated_at'
    sort_order = 'DESC'
    status_filter = 'Awaiting'
    limit = 10
    offset = 0
    supported_sort_keys = ['updated_at', 'store', 'notes', 
                'store_order_id', 'order_date', 'items', 'recipient', 'status' ]
    supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
    supported_status_filters = ['all', 'awaiting', 'onhold', 'cancelled', 'scanned']


    # Get passed in parameter variables if they are valid.
    limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0

    sort_key = params[:sort] if !params[:sort].nil? && 
      supported_sort_keys.include?(params[:sort])

    sort_order = params[:order] if !params[:order].nil? && 
      supported_order_keys.include?(params[:order])

    status_filter = params[:filter] if !params[:filter].nil? && 
      supported_status_filters.include?(params[:filter])
    
      #overrides

    if sort_key == 'store_order_id'
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

    #todo status filters to be implemented
    if status_filter == 'all'
      if sort_key == 'store'
        @orders = Order.find_by_sql("SELECT orders.* FROM orders, stores WHERE "+
        "orders.store_id = stores.id ORDER BY stores.name "+
        sort_order+" LIMIT "+limit+" OFFSET "+offset)
      elsif sort_key == 'items'
        @orders = Order.find_by_sql("SELECT orders.* FROM orders, order_items"+ 
            " WHERE order_items.order_id = orders.id GROUP BY order_items.order_id ORDER BY count "+sort_order+" LIMIT "+limit+" OFFSET "+offset)
      else
      @orders = Order.limit(limit).offset(offset).order(sort_key+" "+sort_order)
      end
    else
      if sort_key == 'store'
      @orders = Order.find_by_sql("SELECT orders.* FROM orders, stores WHERE orders.status='"+status_filter+
        "' AND orders.store_id = stores.id ORDER BY stores.name "+
        sort_order+" LIMIT "+limit+" OFFSET "+offset)
      elsif sort_key == 'items'
        @orders = Order.find_by_sql("SELECT orders.*, count(order_items.id) AS count FROM orders, order_items"+ 
            " WHERE orders.status='"+status_filter+"' AND order_items.order_id = orders.id GROUP BY order_items.order_id "+
            "ORDER BY count "+sort_order+" LIMIT "+limit+" OFFSET "+offset)
      else
      @orders = Order.limit(limit).offset(offset).order(sort_key+" "+sort_order).where(:status=>status_filter)
      end
    end

    @orders_result = []

    @orders.each do |order|
    @order_hash = Hash.new
    @order_hash['id'] = order.id
    if !order.store_id.nil?
      @order_hash['store_name'] = Store.find(order.store_id).name
    else
      @order_hash['store_name'] = ''
    end
    @order_hash['notes'] = order.notes_internal
    @order_hash['ordernum'] = order.increment_id
    @order_hash['orderdate'] = order.order_placed_time
    @order_hash['itemslength'] = OrderItem.where(:order_id=>order.id).length
    @order_hash['status'] = order.status
    @order_hash['recipient'] = "#{order.firstname} #{order.lastname}"
    @orders_result.push(@order_hash)
    end
    
    @result['orders'] = @orders_result

    respond_to do |format|
          format.json { render json: @result}
      end
  end

  def duplicateorder

    @result = Hash.new
    @result['status'] = true
    if params[:select_all]
      #todo: implement search and filter by status
      @orders = params[:orderArray]
    else
      @orders = params[:orderArray]
    end
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
    if params[:select_all]
      #todo: implement search and filter by status
      @orders = params[:orderArray]
    else
      @orders = params[:orderArray]
    end
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
    limit = 10
    offset = 0
    # Get passed in parameter variables if they are valid.
    limit = params[:limit] if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset] if !params[:offset].nil? && params[:offset].to_i >= 0

    if !params[:search].nil? && params[:search] != ''
      search = params[:search]
      
      #todo: include sku and storename in search as well in future.
      @products = Order.find_by_sql("SELECT * from ORDERS WHERE 
                      increment_id like '%"+search+"%' OR status like '%"+search+"%' LIMIT #{limit} 
                      OFFSET #{offset}")

      @orders_result = []

      @orders.each do |order|
      @order_hash = Hash.new
      @order_hash['id'] = order.id
      @order_hash['store_name'] = order.name
      @order_hash['notes'] = order.notes_internal
      @order_hash['ordernum'] = order.increment_id
      @order_hash['orderdate'] = order.order_placed_time
      @order_hash['itemslength'] = order.order_items
      @order_hash['status'] = order.status
      @order_hash['recipient'] = order.firstname +" "+order.lastname
      @orders_result.push(@order_hash)
      end
      
      
      @result['orders'] = @orders_result
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
    if params[:select_all]
      #todo: implement search and filter by status
      @orders = params[:orderArray]
    else
      @orders = params[:orderArray]
    end
    unless @orders.nil?
      @orders.each do|order|
        @order = Order.find(order["id"])
        @order.status = order["status"]
        unless @order.save
          @result['status'] = false
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
        productsku = ProductSku.where(:sku => orderitem.sku)
        if productsku.length > 0
           @products = Product.where(productsku.first.product_id)
           if @products.length > 0
            @orderitem['productinfo'] =@products.first
           end
          @orderitem['productimages'] = ProductImage.where(:product_id=>productsku.first.product_id)
        else
          @orderitem['productinfo'] = nil
          @orderitem['productimages'] = nil
        end
        @result['order']['items'].push(@orderitem)
      end
      @result['order']['storeinfo'] = @order.store

      #setting user permissions for add and remove items permitted
      @result['order']['add_items_permitted'] = current_user.add_order_items
      @result['order']['remove_items_permitted'] = current_user.remove_order_items
      @result['order']['activities'] = @order.order_activities
      @result['order']['exception'] = @order.order_exceptions
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

    @order = Order.find(params[:id])

    if @order.order_exceptions.nil? 
      @exception = OrderExceptions.new
      @exception.order_id = @order.id
    else
      @exception = @order.order_exceptions
    end

    @exception.reason = params[:reason]
    @exception.description = params[:description]
    @exception.user_id = params[:user_id]

    if @exception.save
      @order.addactivity("Order Exception Recorded", current_user.name)
    else
      @result['status'] &= false
      @result['messages'].push('Could not save order with exception')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def clearexception
    @result = Hash.new
    @result['status'] = true

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

    @order = Order.find(params[:id])
    @product = Product.find(params[:productid])

    @skus = ProductSku.where(:product_id=>@product.id).where(:purpose=>'primary')
    if @skus.length > 0
      @orderitem = OrderItem.new
      @orderitem.price = params[:price]
      @orderitem.qty = params[:qty]
      @orderitem.row_total = params[:price].to_f * params[:qty].to_f
      @orderitem.sku = @skus.first.sku
      @order.order_items << @orderitem

      if !@order.save
        @result['status'] &= false
        @result['messages'].push("Adding item to order failed")
      end
    else
        @result['status'] &= false
        @result['messages'].push("Could not find any SKU with product id:"+@productid)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

  def removeitemfromorder
    @result = Hash.new
    @result['status'] = true

    @orderitem = OrderItem.find(params[:orderitem])

    if !@orderitem.nil?
      if !@orderitem.destroy
        @result['status'] &= false
        @result['messages'].push("Remove item from order")
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
  
end
