class OrdersController < ApplicationController
  before_filter :authenticate_user!, except: [:import_shipworks]
  include OrdersHelper
  include ProductsHelper
  include SettingsHelper
  include ApplicationHelper


  # Import orders from store based on store id
  def importorders
    store = Store.find(params[:id])
    @result = Hash.new

    @result['status'] = true
    @result['messages'] = []
    @result['total_imported'] = 0
    @result['success_imported'] = 0
    @result['previous_imported'] = 0
    @result['activestoreindex'] = 0

    import_result = nil

    if !params[:activestoreindex].nil?
      @result['activestoreindex'] = params[:activestoreindex]
    end

    if current_user.can? 'import_orders'
      begin
        #import if magento products
        if store.store_type == 'Amazon'
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::AmazonHandler.new(store))
          import_result = context.import_orders
        elsif store.store_type == 'Ebay'
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::EbayHandler.new(store))
          import_result = context.import_orders
        elsif store.store_type == 'Magento'
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::MagentoHandler.new(store))
          import_result = context.import_orders
        elsif store.store_type == 'Shipstation'
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::ShipstationHandler.new(store))
          import_result = context.import_orders
        elsif store.store_type == 'Shipstation API 2'
          context = Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::ShipstationRestHandler.new(store))
          import_result = context.import_orders
        end
      rescue Exception => e
        @result['status'] = false
        @result['messages'].push(e.message)
        puts e.backtrace
      end
    else
      @result['status'] = false
      @result['messages'].push('You do not have the permission to import orders')
    end

    if !import_result.nil?
      import_result[:messages].each do |message|
        @result['messages'].push(message)
      end
      @result['status'] = !!import_result[:status]
      @result['total_imported'] = import_result[:total_imported]
      @result['success_imported'] = import_result[:success_imported]
      @result['previous_imported'] = import_result[:previous_imported]
    end

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def import_shipworks
    #find store by using the auth_token
    auth_token = params[:auth_token]
    logger.info(auth_token)
    unless auth_token.nil? || request.headers["HTTP_USER_AGENT"] != 'shipworks'
      begin
        credential = ShipworksCredential.find_by_auth_token(auth_token)
        unless credential.nil? || !credential.store.status
          import_item = ImportItem.find_by_store_id(credential.store.id)
          if import_item.nil?
            import_item = ImportItem.new
            import_item.store_id = credential.store.id
          end
          import_item.status = 'in_progress'
          import_item.current_increment_id = ''
          import_item.success_imported = 0
          import_item.previous_imported = 0
          import_item.current_order_items = -1
          import_item.current_order_imported_item = -1
          import_item.to_import = 1
          import_item.save
          Groovepacker::Store::Context.new(
            Groovepacker::Store::Handlers::ShipworksHandler.new(credential.store,import_item)).import_order(params["ShipWorks"]["Customer"]["Order"])
          import_item.status = 'completed'
          import_item.save
          render nothing: true
        else
          render status: 401, nothing: true
        end
      rescue Exception => e
        logger.info(e.message)
        logger.info(e.backtrace.inspect)
        import_item.status = 'failed'
        import_item.message = e.message
        import_item.save
        render status: 401, nothing: true
      end
    else
      render status: 401, nothing: true
    end
  end

  # PUT /orders/1
  # PUT /orders/1.json
  def update
    @order = Order.find(params[:id])
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []

    #Everyone can create notes from Packer
    @order.notes_fromPacker = params[:order]['notes_fromPacker']

    if current_user.can?('create_edit_notes')
      @order.notes_internal = params[:order]['notes_internal']
      @order.notes_toPacker = params[:order]['notes_toPacker']
    elsif @order.notes_internal != params[:order]['notes_internal'] ||
          @order.notes_toPacker != params[:order]['notes_toPacker']
      @result['status'] = false
      @result['messages'].push('You do not have the permissions to edit notes')
    end

    if current_user.can?('add_edit_order_items')
      @order.firstname = params[:order]['firstname']
      @order.lastname = params[:order]['lastname']
      @order.company = params[:order]['company']
      @order.address_1 = params[:order]['address_1']
      @order.address_2 = params[:order]['address_2'] unless params[:order]['address_2'].nil?
      @order.city = params[:order]['city']
      @order.state = params[:order]['state']
      @order.postcode = params[:order]['postcode']
      @order.country = params[:order]['country']
      @order.email = params[:order]['email']
      @order.increment_id = params[:order]['increment_id']
      @order.order_placed_time = params[:order]['order_placed_time']
      @order.customer_comments = params[:order]['customer_comments']
      @order.scanned_on = params[:order]['scanned_on']
      @order.tracking_num = params[:order]['tracking_num']
      @order.seller_id = params[:order]['seller_id']
      @order.order_status_id = params[:order]['order_status_id']
      @order.order_number = params[:order]['order_number']
      @order.ship_name = params[:order]['ship_name']
      @order.notes_from_buyer = params[:order]['notes_from_buyer']
      @order.note_confirmation = params[:order]['note_confirmation']
      @order.shipping_amount = params[:order]['shipping_amount'] unless params[:order]['shipping_amount'].nil?
      @order.order_total = params[:order]['order_total'] unless params[:order]['order_total'].nil?
      @order.weight_oz = params[:order]['weight_oz'] unless params[:order]['weight_oz'].nil?
    elsif @order.firstname != params[:order]['firstname'] ||
          @order.lastname != params[:order]['lastname'] ||
          @order.company != params[:order]['company'] ||
          @order.address_1 != params[:order]['address_1'] ||
          @order.address_2 != params[:order]['address_2'] ||
          @order.city != params[:order]['city'] ||
          @order.state != params[:order]['state'] ||
          @order.postcode != params[:order]['postcode'] ||
          @order.country != params[:order]['country'] ||
          @order.email != params[:order]['email'] ||
          @order.increment_id != params[:order]['increment_id'] ||
          @order.order_placed_time != params[:order]['order_placed_time'] ||
          @order.customer_comments != params[:order]['customer_comments'] ||
          @order.scanned_on != params[:order]['scanned_on'] ||
          @order.tracking_num != params[:order]['tracking_num'] ||
          @order.seller_id != params[:order]['seller_id'] ||
          @order.order_status_id != params[:order]['order_status_id'] ||
          @order.order_number != params[:order]['order_number'] ||
          @order.ship_name != params[:order]['ship_name'] ||
          @order.notes_from_buyer != params[:order]['notes_from_buyer'] ||
          @order.shipping_amount != params[:order]['shipping_amount'] ||
          @order.order_total != params[:order]['order_total'] ||
          @order.weight_oz != params[:order]['weight_oz'] ||
          @order.note_confirmation != params[:order]['note_confirmation']
      @result['status'] = false
      @result['messages'].push('You do not have enough permissions to edit the order')
    end

    unless @order.save
      @result['status'] &= false
      @result['messages'] = @order.errors.full_messages
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
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
    #GroovRealtime::emit('test',{does:'it work for user '+current_user.username+'?'})
    #GroovRealtime::emit('test',{does:'it work for tenant '+Apartment::Tenant.current_tenant+'+'?'},:tenant)
    #GroovRealtime::emit('test',{does:'it work for global?'},:global)
    @result['orders'] = make_orders_list(@orders)
    @result['orders_count'] = get_orders_count()

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def duplicateorder

    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['notice_messages'] = []
    @orders = list_selected_orders

    if current_user.can?('add_edit_order_items')
      unless @orders.nil?
        @orders.each do|order|

          @order = Order.find(order["id"])

          @neworder = @order.dup
          index = 0
          temp_increment_id = ''

          begin
            temp_increment_id = @order.increment_id + "(duplicate"+index.to_s+ ")"
            @neworder.increment_id = temp_increment_id
            @orderslist = Order.where(:increment_id=>temp_increment_id)
            index = index + 1
          end while(!@orderslist.nil? && @orderslist.length > 0)

          if !@neworder.save(:validate => false)
            @result['status'] = false
            @result['error_messages'] = @neworder.errors.full_messages
          else
            #add activity
            @order_items = @order.order_items
            @order_items.each do |order_item|
              neworder_item = order_item.dup
              neworder_item.order_id = @neworder.id
              neworder_item.save
            end
            username = current_user.name
            @neworder.addactivity("Order duplicated", username)
          end
        end
      end
    else
      @result['status'] = false
      @result['error_messages'].push("You do not have enough permissions to duplicate order")
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteorder
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['notice_messages'] = []
    @orders = list_selected_orders
    if current_user.can? 'add_edit_order_items'
      unless @orders.nil?
        @orders.each do|order|
          @order = Order.find(order["id"])
          # in order to adjust inventory on deletion of order assign order status as 'cancelled'
          @order.status = 'cancelled'
          @order.save
          if @order.destroy
            @result['status'] &= true
          else
            @result['status'] &= false
            @result['error_messages'] = @order.errors.full_messages
          end
        end
      end
    else
      @result['status'] = false
      @result['error_messages'].push("You do not have enough permissions to delete order")
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

      @orders = do_search(false)

      @result['orders'] = make_orders_list(@orders['orders'])
      @result['orders_count'] = get_orders_count()
      @result['orders_count']['search'] = @orders['count']

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
    @result['error_messages'] = []
    @result['notice_messages'] = []

    @orders = list_selected_orders
    if current_user.can? 'change_order_status'
      unless @orders.nil?
        @orders.each do|order|
          @order = Order.find(order['id'])
          @order.update_inventory_level &= false
          if @order.status =='scanned' && params[:status] =='awaiting'
            @order.reset_scanned_status
            @result['notice_messages'].push('Items in scanned orders have already been removed from inventory so no further inventory adjustments will be made during packing.')
          end
          @order.status = params[:status]
          @order.update_inventory_levels_for_status_change(params[:option]) unless params[:option].nil?
          unless @order.save
            @result['status'] = false
            @result['error_messages'] = @order.errors.full_messages
          end
        end
      end
    else
      @result['status'] = false
      @result['error_messages'].push("You do not have enough permissions to delete order")
    end
    @order.update_inventory_level = true
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
            @orderitem['qty_on_hand'] +=  inventory.available_inv.to_i
          end
          if product.product_inventory_warehousess.length > 0
            @orderitem['location_primary'] =
            product.primary_warehouse.nil? ? "" : product.primary_warehouse.location_primary
                #ProductInventoryWarehouses.where(product_id:product.id,inventory_warehouse_id: current_user.inventory_warehouse_id).first.location_primary
          end
          @orderitem['sku'] = product.primary_sku
          @orderitem['barcode'] = product.primary_barcode
          @orderitem['image'] = product.primary_image

        end
        @result['order']['items'].push(@orderitem)
      end
      @result['order']['storeinfo'] = @order.store

      #setting user permissions for add and remove items permitted
      @result['order']['add_items_permitted'] = current_user.can? 'add_edit_order_items'
      @result['order']['remove_items_permitted'] = current_user.can? 'add_edit_order_items'
      @result['order']['activities'] = @order.order_activities

      #Retrieve Unacknowledged activities
      @result['order']['unacknowledged_activities'] = @order.unacknowledged_activities
      @result['order']['exception'] = @order.order_exceptions if current_user.can?('view_packing_ex')
      @result['order']['exception']['assoc'] =
        User.find(@order.order_exceptions.user_id) if current_user.can?('view_packing_ex') && !@order.order_exceptions.nil? && @order.order_exceptions.user_id !=0

      @result['order']['users'] = User.all

      #add a user with name of nobody to display in the list
      dummy_user = User.new
      dummy_user.name = 'Nobody'
      dummy_user.id = 0
      @result['order']['users'].unshift(dummy_user)

      #add packing_slip_size and packing_slip_orientation
      # @result['order']['packing_slip_size'] = GeneralSetting.get_packing_slip_size
      # @result['order']['packing_slip_orientation'] = GeneralSetting.get_packing_slip_orientation

      if !@order.packing_user_id.nil?
        @result['order']['users'].each do |user|
          if user.id == @order.packing_user_id
            user.name = "#{user.name} (Packing User)"
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


  def recordexception
    @result = Hash.new
    @result['status'] = true
    username = current_user.name
    @result['messages'] = []

    @order = Order.find(params[:id])

    if !params[:reason].nil?
      if (current_user.can?('create_packing_ex') &&  @order.order_exceptions.nil?) ||
          (current_user.can?('edit_packing_ex') &&  !@order.order_exceptions.nil?)
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
          @order.addactivity("Order Exception Associated with #{username} - Recorded", current_user.name)
        else
          @result['status'] &= false
          @result['messages'].push('Could not save order with exception')
        end
      else
        @result['status'] &= false
        @result['messages'].push('Insufficient permissions')
        @result['messages'].push(current_user.role)
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
      if current_user.can? 'edit_packing_ex'
        if @order.order_exceptions.destroy
          @order.addactivity("Order Exception Cleared", current_user.name)
        else
          @result['status'] &= false
          @result['messages'].push('Error clearing exceptions')
        end
      else
        @result['status'] &= false
        @result['messages'].push('You can not edit exceptions')
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
    @result['messages'] = []
    if current_user.can? 'add_edit_order_items'
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

          if @orderitem.save
            product_skus = product.product_skus
            if product_skus.length > 0
              product_sku = product_skus.first.sku
            end
            username = current_user.name
            @order.addactivity("Item with sku " + product_sku.to_s + " added", username)
            if product.is_kit == 1
              kit_skus = ProductKitSkus.where(:product_id => @orderitem.product_id)
              kit_skus.each do |kit_sku|
                kit_sku.add_product_in_order_items
              end
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
    else
      @result['status'] = false
      @result['messages'].push('You can not add or edit order items')
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
    if current_user.can? 'add_edit_order_items'
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
    else
      @result['status'] = false
      @result['messages'].push('You can not add or edit order items')
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
    if current_user.can? 'add_edit_order_items'
      @orderitem = OrderItem.find(params[:orderitem])

      if @orderitem.nil?
        @result['status'] &= false
        @result['messages'].push("Could not find order item")
      else
        @orderitem.each do |item|
          product = item.product
          if !product.nil?
            product_skus = product.product_skus
            if product_skus.length > 0
              sku = product_skus.first.sku
            end
          end

          username = current_user.name
          if item.remove_order_item_kit_products && item.destroy
            item.order.update_order_status
            item.order.addactivity("Item with sku " + sku.to_s + " removed", username)
          else
            @result['status'] &= false
            @result['messages'].push("Removed items from order failed")
          end

        end
      end
    else
      @result['status'] = false
      @result['messages'].push('You can not add or edit order items')
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
        if current_user.can? 'add_edit_order_items'
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
              begin
                current_product = Product.find(current_item['iteminfo']['product_id'])
                updatelist(current_product,'name',current_item['productinfo']['name'])
                updatelist(current_product,'is_skippable',current_item['productinfo']['is_skippable'])
                updatelist(current_product,'qty',current_item['qty_on_hand'])
                updatelist(current_product,'location_name',current_item['location'])
                updatelist(current_product,'sku',current_item['sku'])
              rescue Exception => e
                
              end
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

        else
          @result['status'] = false
          @result['messages'].push('Couldn\'t rollback because you can not add or edit order items')
        end
        if current_user.can? 'edit_packing_ex'
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
        else
          @result['status'] = false
          @result['messages'].push('Couldn\'t rollback because you can not edit packing exceptions')
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
          #"ordernum" => "increment_id",
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
          arr = params[:value].blank? ? [] : params[:value].split(' ')
          @order.firstname = arr.shift
          @order.lastname = arr.join(' ')
        elsif params[:var] == 'notes_from_packer' ||
              (params[:var] == 'notes' && current_user.can?('create_edit_notes')) ||
              current_user.can?('add_edit_order_items')
          key = accepted_data[params[:var]]
          @order[key] = params[:value]
        else
          @result['status']&= false
          @result['error_msg'] = 'Insufficient permissions'
        end
        if @result['status']
          unless @order.save
            @result['status'] &= false
            @result['error_msg'] = 'Could not save order info'
          end
        end
      else
        @result['status'] &= false
        @result['error_msg'] = 'Unknown field'
      end
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end


  def generate_pick_list
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new
    @pick_list = []
    @depends_pick_list = []

    @orders = list_selected_orders

    unless @orders.nil?
      @orders.each do |order|
        order = Order.find(order['id'])
        store = order.store
        inventory_warehouse_id = 0
        if !store.nil? && !store.inventory_warehouse.nil?
          inventory_warehouse_id = store.inventory_warehouse_id
        end
        single_pick_list_obj =
          Groovepacker::PickList::SinglePickListBuilder.new
        individual_pick_list_obj =
          Groovepacker::PickList::IndividualPickListBuilder.new
        depends_pick_list_obj =
          Groovepacker::PickList::DependsPickListBuilder.new
        order.order_items.each do |order_item|
          if !order_item.product.nil?
            # for single products which are not kit
            if order_item.product.is_kit == 0
              @pick_list = single_pick_list_obj.build(
                order_item.qty, order_item.product, @pick_list, inventory_warehouse_id)
            else # for products which are kits
              if order_item.product.kit_parsing == 'single'
                @pick_list = single_pick_list_obj.build(
                  order_item.qty, order_item.product, @pick_list, inventory_warehouse_id)
              else #for individual kits
                if order_item.product.kit_parsing == 'individual'
                  @pick_list = individual_pick_list_obj.build(
                  order_item.qty, order_item.product, @pick_list, inventory_warehouse_id)
                else #for automatic depends kits
                  if order_item.product.kit_parsing == 'depends'
                    @depends_pick_list = depends_pick_list_obj.build(
                    order_item.qty, order_item.product, @depends_pick_list, inventory_warehouse_id)
                  end
                end
              end
            end
          end
        end
      end
    end
    unless @pick_list.length == 0
      @pick_list = @pick_list.sort_by  do |h|
        if h['primary_location'].blank?
          ''
        else
          h['primary_location']
        end
      end
    end
    unless @depends_pick_list.length == 0
      @depends_pick_list = @depends_pick_list.sort_by  do |h|
        unless h['individual'].length == 0
          h['individual'] = h['individual'].sort_by do |hash|
            if hash['primary_location'].blank?
              ''
            else
              hash['primary_location']
            end
          end
        end
        if h['single'].length == 0 || h['single'][0]['primary_location'].blank?
          ''
        else
          h['single'][0]['primary_location']
        end
      end

    end
    puts @depends_pick_list

    respond_to do |format|
      format.html
      format.json {
        result['data']['pick_list'] = @pick_list
        result['data']['depends_pick_list'] = @depends_pick_list
        time = Time.now
        file_name = 'pick_list_'+time.strftime('%d_%b_%Y')
        result['data']['pick_list_file_paths'] = '/pdfs/'+ file_name + '.pdf'
        render :pdf => file_name,
        :template => 'orders/generate_pick_list',
        :orientation => 'portrait',
        :page_height => '8in',
        :save_only => true,
        :page_width => '11.5in',
        :margin => {:top => '20',
                    :bottom => '20',
                    :left => '10',
                    :right => '10'},
        :header=> {:spacing=>5,:right => '[page] of [topage]'},
        :footer=> {:spacing=>1},
        :handlers =>[:erb],
        :formats => [:html],
        :save_to_file => Rails.root.join('public','pdfs', "#{file_name}.pdf")

        render json: result
      }
      format.pdf {

      }
    end
  end

  def generate_packing_slip
    result = Hash.new
    result['status'] = false
    if GeneralSetting.get_packing_slip_size == '4 x 6'
      @page_height = '6'
      @page_width = '4'
    else
      @page_height = '11'
      @page_width = '8.5'
    end
    @size = GeneralSetting.get_packing_slip_size
    @orientation = GeneralSetting.get_packing_slip_orientation
    @result = Hash.new
    @result['data'] = Hash.new
    @result['data']['packing_slip_file_paths'] = []

    if @orientation == 'landscape'
      @page_height = @page_height.to_f/2
      @page_height = @page_height.to_s
    end
    @header = ''

    @file_name = Apartment::Tenant.current_tenant+Time.now.strftime('%d_%b_%Y_%I:%M_%p')
    @orders = []
    orders = list_selected_orders
    orders.each do |order|
      single_order = Order.find(order['id'])
      unless single_order.nil?
        @orders.push({id:single_order.id, increment_id:single_order.increment_id})
      end
    end
    unless @orders.empty?

      GenerateBarcode.where('updated_at < ?',24.hours.ago).delete_all
      @generate_barcode = GenerateBarcode.new
      @generate_barcode.user_id = current_user.id
      @generate_barcode.current_order_position = 0
      @generate_barcode.total_orders = @orders.length
      @generate_barcode.next_order_increment_id = @orders.first[:increment_id] unless @orders.first.nil?
      @generate_barcode.status = 'scheduled'

      @generate_barcode.save
      delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(@orders, Apartment::Tenant.current_tenant, @result, @page_height,@page_width,@orientation,@file_name, @size, @header,@generate_barcode.id)
      @generate_barcode.delayed_job_id = delayed_job.id
      @generate_barcode.save
      result['status'] = true
    end
    render json: result
  end

  def cancel_packing_slip
    result = Hash.new
    result['status'] = true
    result['success_messages'] = []
    result['notice_messages'] = []
    result['error_messages'] = []

    if params[:id].nil?
      result['status'] = false
      result['error_messages'].push('No id given. Can not cancel generating')
    else
      barcode = GenerateBarcode.find_by_id(params[:id])
      unless barcode.nil?
        barcode.cancel = true
        unless barcode.status =='in_progress'
          barcode.status = 'cancelled'
          begin
            the_delayed_job = Delayed::Job.find(barcode.delayed_job_id)
            unless the_delayed_job.nil?
              the_delayed_job.destroy
            end
          rescue Exception => e
          end
        end

        if barcode.save
          result['notice_messages'].push('Pdf generation marked for cancellation. Please wait for acknowledgement.')
        end
      else
        result['error_messages'].push('No barcode found with the id.')
      end
    end


    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def order_items_export
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    result['filename'] = ''
    selected_orders = list_selected_orders(true)
    general_settings = GeneralSetting.all.first
    items_list = {}
    increment = 0


    if selected_orders.nil?
      result['status'] = false
      result['messages'].push('No orders selected')
    else
      if general_settings.export_items == 'disabled'
        result['status'] = false
        result['messages'].push('Order export items is disabled.')
      else
        filename = 'groove-order-items-'+Apartment::Tenant.current_tenant+'-'+Time.now.strftime('%d_%b_%Y_%H_%M_%S_%Z')+'.csv'
        row_map = {
            :quantity =>'',
            :product_name=>'',
            :primary_sku =>'',
            :primary_barcode =>'',
            :secondary_barcode => '',
            :tertiary_barcode => '',
            :location_primary => '',
            :location_secondary => '',
            :location_tertiary => '',
            :image_url => '',
            :available_inventory=>'',
            :product_status => '',
            :order_number => '',
        }
        selected_orders.each do |single_order|

          order = Order.find(single_order['id'].to_i)
          inventory_warehouse_id = InventoryWarehouse.where(:is_default => 1).first.id
          unless order.store.nil? || order.store.inventory_warehouse.nil?
            inventory_warehouse_id = order.store.inventory_warehouse_id
          end
          order.order_items.each do |single_item|
            unless single_item.product.nil?
              if single_item.product.is_kit == 0 || ['single','depends'].include?(single_item.product.kit_parsing)
                product_sku = single_item.product.product_skus.order("product_skus.order ASC").first
                unless product_sku.nil?

                  product_barcodes = single_item.product.product_barcodes.order("product_barcodes.order ASC")
                  product_inventory_warehouse = single_item.product.get_inventory_warehouse_info(inventory_warehouse_id)
                  if items_list.has_key?(product_sku.sku) && general_settings.export_items == 'by_sku'

                    items_list[product_sku.sku][:quantity] = items_list[product_sku.sku][:quantity] + single_item.qty

                  else
                    single_row_list = row_map.dup
                    single_row_list[:quantity] = single_item.qty
                    single_row_list[:product_name]= single_item.product.name
                    single_row_list[:primary_sku] = product_sku.sku
                    unless product_barcodes.length == 0
                      single_row_list[:primary_barcode] = product_barcodes[0].barcode
                      unless product_barcodes.length < 2
                        single_row_list[:secondary_barcode] = product_barcodes[1].barcode
                      end
                      unless product_barcodes.length < 3
                        single_row_list[:tertiary_barcode] = product_barcodes[2].barcode
                      end
                    end

                    unless product_inventory_warehouse.nil?
                      single_row_list[:location_primary] = product_inventory_warehouse.location_primary
                      single_row_list[:location_secondary] = product_inventory_warehouse.location_secondary
                      single_row_list[:location_tertiary] = product_inventory_warehouse.location_tertiary
                      single_row_list[:available_inventory]=product_inventory_warehouse.available_inv
                    end
                    unless single_item.product.primary_image.nil?
                      single_row_list[:image_url] = single_item.product.primary_image
                    end


                    single_row_list[:product_status] = single_item.product.status
                    single_row_list[:order_number] = order.increment_id

                    if general_settings.export_items == 'by_sku'
                      items_list[product_sku.sku] = single_row_list
                    else
                      items_list[increment] = single_row_list
                      increment = increment + 1
                    end
                  end
                end
              end

              if single_item.product.is_kit == 1 && ['individual','depends'].include?(single_item.product.kit_parsing)
                single_item.product.product_kit_skuss.each do |kit_item|
                  product_sku = kit_item.option_product.product_skus.order("product_skus.order ASC").first
                  unless product_sku.nil?
                    product_barcodes = kit_item.option_product.product_barcodes.order("product_barcodes.order ASC")
                    product_inventory_warehouse = kit_item.option_product.get_inventory_warehouse_info(inventory_warehouse_id)
                    if items_list.has_key?(product_sku.sku) && general_settings.export_items == 'by_sku'

                      items_list[product_sku.sku][:quantity] = items_list[product_sku.sku][:quantity] + (kit_item.qty*single_item.qty)

                    else
                      single_row_list = row_map.dup
                      single_row_list[:quantity] = (kit_item.qty*single_item.qty)
                      single_row_list[:product_name]= kit_item.option_product.name
                      single_row_list[:primary_sku] = product_sku.sku
                      unless product_barcodes.length == 0
                        single_row_list[:primary_barcode] = product_barcodes[0].barcode
                        unless product_barcodes.length < 2
                          single_row_list[:secondary_barcode] = product_barcodes[1].barcode
                        end
                        unless product_barcodes.length < 3
                          single_row_list[:tertiary_barcode] = product_barcodes[2].barcode
                        end
                      end

                      unless product_inventory_warehouse.nil?
                        single_row_list[:location_primary] = product_inventory_warehouse.location_primary
                        single_row_list[:location_secondary] = product_inventory_warehouse.location_secondary
                        single_row_list[:location_tertiary] = product_inventory_warehouse.location_tertiary
                        single_row_list[:available_inventory]=product_inventory_warehouse.available_inv
                      end
                      unless kit_item.option_product.primary_image.nil?
                        single_row_list[:image_url] = kit_item.option_product.primary_image
                      end


                      single_row_list[:product_status] = kit_item.option_product.status
                      single_row_list[:order_number] = order.increment_id
                      if general_settings.export_items == 'by_sku'
                        items_list[product_sku.sku] = single_row_list
                      else
                        items_list[increment] = single_row_list
                        increment = increment + 1
                      end
                    end
                  end
                end
              end

            end
          end
        end
        CSV.open(Rails.root.join('public','pdfs', filename ),'wb') do |csv|
          csv << row_map.keys
          items_list.values.each do |line|
            csv << line.values
          end
        end
        result['filename'] = 'pdfs/'+filename
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def import_all
    # import_orders_helper()

    result = Hash.new
    result['status'] = true
    result['success_messages'] = []
    result['error_messages'] = []
    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty?
      if Store.where("status = '1' AND store_type != 'system'").length > 0
        order_summary_info = OrderImportSummary.new
        order_summary_info.user_id = current_user.id
        order_summary_info.status = 'not_started'
        order_summary_info.save
        # call delayed job
        tenant = Apartment::Tenant.current_tenant
        import_orders_obj = ImportOrders.new
        Delayed::Job.where(queue: "importing_orders_#{tenant}").destroy_all
        import_orders_obj.delay(:run_at => 1.seconds.from_now,:queue => "importing_orders_#{tenant}").import_orders  tenant
        # import_orders_obj.import_orders
        result['success_messages'].push('Scouring the interwebs for new orders...')
      else
        result['error_messages'].push('You currently have no Active Stores in your Store List')
        result['status'] = false
      end
    else
      #Send a message back to the user saying that import is already in progress
      result['error_messages'].push('Import is in progress')
      result['status'] = false
    end
    render json: result
  end

  # params[:store_id] params[:import_type]
  def import
    result = {
      status: true,
      success_messages: [],
      error_messages: []
    }

    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty?
      store = Store.find(params[:store_id])
      tenant = Apartment::Tenant.current_tenant
      Delayed::Job.where(queue: "importing_orders_#{tenant}").destroy_all
      import_orders_obj = ImportOrders.new
      import_params = {tenant: tenant, store: store, import_type: params[:import_type], user: current_user}
      import_orders_obj.import_order_by_store import_params
    else
      result[:status] = false
      result[:error_messages] << "Import is in progress"
    end

    render json: result
  end

  def cancel_import
    result = {
      status: true,
      success_messages: [],
      error_messages: []
    }

    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty?
      result[:status] = false
      result[:error_messages] << "No imports are in progress"
    else
      order_summary = order_summary.first

      order_summary.import_items.each do |import_item|
        import_item.update_attributes(
          status: 'cancelled') if import_item.store_id == params[:store_id]
      end
    end

    render json: result
  end

  def confirmation

  end
  def match
    email = params['confirm']['email']
    postcode = params['confirm']['postcode']

    @matching_orders = Order.where('postcode LIKE ?',"#{postcode}%")
    unless @matching_orders.nil?
      @matching_orders = @matching_orders.where(email: email)
    end
    render 'match'
  end

  private

  def do_search(results_only = true)
    sort_key = 'updated_at'
    sort_order = 'DESC'
    limit = 10
    offset = 0
    supported_sort_keys = ['updated_at', 'notes',
                           'ordernum', 'order_date', 'itemslength', 'recipient', 'status','email','tracking_num','city','state','postcode','country' ]
    supported_order_keys = ['ASC', 'DESC' ] #Caps letters only
    sort_key = params[:sort] if !params[:sort].nil? &&
        supported_sort_keys.include?(params[:sort])

    sort_order = params[:order] if !params[:order].nil? &&
        supported_order_keys.include?(params[:order])

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

    # Get passed in parameter variables if they are valid.
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0
    search = ActiveRecord::Base::sanitize('%'+params[:search]+'%')
    base_query = 'Select orders.*, sum(order_items.qty) AS itemslength from orders LEFT JOIN stores ON (orders.store_id = stores.id)
                      LEFT JOIN order_items ON (order_items.order_id = orders.id) WHERE
                      increment_id like '+search+' OR non_hyphen_increment_id like '+ search +
                      ' OR email like '+search+' OR CONCAT(IFNULL(firstname,"")," ",IFNULL(lastname,"")) like '+search+' OR postcode like '+search+' GROUP BY orders.id Order BY '+sort_key+' '+sort_order
    query_add = ''
    unless params[:select_all] || params[:inverted]
      query_add = " LIMIT #{limit} OFFSET #{offset}"
    end
    result_rows = Order.find_by_sql(base_query+query_add)
    if results_only
      result = result_rows
    else
      result = Hash.new
      result['orders'] = result_rows
      result['count'] = Order.count_by_sql('SELECT COUNT(*) as count from ('+ base_query+') as tmp_order')
    end
    #todo: include sku and storename in search as well in future.
    return result
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
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0

    unless params[:select_all] || params[:inverted]
      query_add = " LIMIT "+limit.to_s+" OFFSET "+offset.to_s
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
      unless params[:select_all] || params[:inverted]
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

  def list_selected_orders(sort_by_order_number = false)
    if params[:select_all] || params[:inverted]
      if sort_by_order_number
        params[:sort] = 'ordernum'
        params[:order] = 'ASC'
      end
      if !params[:search].nil? && params[:search] != ''
        result = do_search
      else
        result = do_getorders
      end
    elsif !params[:orderArray].nil?
      if sort_by_order_number
        result = Order.where(:id => params[:orderArray].map(&:values).flatten).order(:increment_id)
      else
        result =  params[:orderArray]
      end
    elsif !params[:id].nil?
      result = Order.find(params[:id])
    else
      if sort_by_order_number
        result = Order.where(:id => params[:order_ids]).order(:increment_id)
      else
        result = Order.where(:id => params[:order_ids])
      end
    end

    result_rows = []
    if params[:inverted] && !params[:orderArray].blank?
      not_in = []
      params[:orderArray].each do |order|
        not_in.push(order['id'])
      end
      result.each do |single_order|
        unless not_in.include? single_order['id']
          result_rows.push(single_order)
        end
      end
    else
      result_rows = result
    end
    return result_rows
  end

  def get_orders_count
    count = Hash.new
    counts = Order.select('status,count(*) as count').where(:status=>['scanned','cancelled','onhold','awaiting','serviceissue']).group(:status)
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
