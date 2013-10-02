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
          @filters ['filter']  = @filter
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
              if Order.where(:store_order_id=>item[:order_id]).length == 0
                @order = Order.new
                @order.store_order_id = item[:order_id]
                @order.status = item[:status]
                @order.storename = item[:store_name]
                @order.store = @store
                line_items = order_info[:items]
                if line_items[:item].is_a?(Hash)
                    @order_item = OrderItem.new
                    @order_item.price = line_items[:item][:price]
                    @order_item.qty = line_items[:item][:qty_ordered]
                    @order_item.row_total= line_items[:item][:row_total]
                    @order_item.sku = line_items[:item][:sku] 
                    @order.order_items << @order_item
                else
                  line_items[:item].each do |line_item|
                    @order_item = OrderItem.new
                    @order_item.price = line_item[:price]
                    @order_item.qty = line_item[:qty_ordered]
                    @order_item.row_total= line_item[:row_total]
                    @order_item.sku = line_item[:sku]
                    @order.order_items << @order_item
                  end
                end

                @shipping = OrderShipping.new

                @shipping.streetaddress1 =  order_info[:shipping_address][:street]
                @shipping.city = order_info[:shipping_address][:city]
                @shipping.region = order_info[:shipping_address][:region]
                @shipping.country = order_info[:shipping_address][:country_id]
                @shipping.postcode = order_info[:shipping_address][:postcode]
                @shipping.email = item[:customer_email]
                @shipping.lastname = order_info[:shipping_address][:firstname]
                @shipping.firstname = order_info[:shipping_address][:lastname]

                @order.order_shipping = @shipping
                if @order.save
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
      
      @eBay = EBay::API.new(@credential.auth_token, 
        ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'], 
        ENV['EBAY_CERT_ID'], :sandbox=>true)

      seller_list =@eBay.GetSellerTransactions(:orderRole=> 'Seller', :orderStatus=>'All', 
        :createTimeFrom=> (Date.today - 3.months).to_datetime,
         :createTimeTo =>(Date.today + 1.day).to_datetime)
      if (seller_list.transactionArray != nil)
        @result['total_imported']  = seller_list.transactionArray.size
      #@result['seller_list'] = seller_list.transactionArray
      #@result['app_id'] = @credential
      seller_list.transactionArray.each do |transaction|
        if Order.where(:store_order_id=>transaction.transactionID).length == 0
          @order = Order.new
          @order.status = transaction.status.completeStatus
          @order.storename = @store.name
          @order.store = @store
          @order.store_order_id = transaction.transactionID

          @order_item = OrderItem.new
          @order_item.price = transaction.item.sellingStatus.currentPrice
          @order_item.qty = transaction.quantityPurchased
          @order_item.row_total= transaction.transactionPrice
          @order_item.sku = transaction.item.itemID

          @order.order_items << @order_item

          @shipping = OrderShipping.new

          @shipping.streetaddress1 = transaction.buyer.buyerInfo.shippingAddress.street1
          @shipping.city = transaction.buyer.buyerInfo.shippingAddress.cityName
          @shipping.region = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
          @shipping.country = transaction.buyer.buyerInfo.shippingAddress.country
          @shipping.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
          if @order.status != 'Complete'
            @shipping.email = transaction.buyer.staticAlias
          end
          @shipping.lastname = transaction.buyer.buyerInfo.shippingAddress.name

          @order.order_shipping = @shipping
          if @order.save
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
      response = mws.orders.list_orders :last_updated_after => 2.months.ago, :order_status => 'Pending'
            #@result['report_id'] = response.body
      
      @orders = response.orders
      if !@orders.nil?
        @result['total_imported'] = @orders.length
        @orders.each do |order|
        if Order.where(:store_order_id=>order.amazon_order_id).length == 0
          @order = Order.new
          @order.status = order.order_status
          @order.store_order_id = order.amazon_order_id
          @order.storename = @store.name
          @order.store = @store
          
          order_items  = mws.orders.list_order_items :amazon_order_id => order.amazon_order_id
          @result['orderitem'] = order_items

          order_items.order_items.each do |item|
            @order_item = OrderItem.new
            @order_item.price = item.item_price.amount
            @order_item.qty = item.quantity_ordered
            @order_item.row_total= item.item_price.amount.to_i * item.quantity_ordered.to_i
            @order_item.sku = item.seller_sku
          end

          @order.order_items << @order_item

          @shipping = OrderShipping.new

          @shipping.streetaddress1 = order.shipping_address.address_line1
          @shipping.city = order.shipping_address.city
          @shipping.region = order.shipping_address.state_or_region
          @shipping.country = order.shipping_address.country
          @shipping.postcode = order.shipping_address.postal_code
          @shipping.email = order.buyer_email
          @shipping.lastname = order.shipping_address.name
          
          @order.order_shipping = @shipping


          if @order.save
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
end
