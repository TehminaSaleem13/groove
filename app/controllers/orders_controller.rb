class OrdersController < ApplicationController

  include OrdersHelper
  include ProductsHelper
  include SettingsHelper


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
        end
      rescue Exception => e
        @result['status'] = false
        @result['messages'].push(e.message)
        puts e.backtrace
      end
    else
      @result['status'] = false
      @result['messages'].push("You do not have the permission to import orders")
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
      format.json { render json: @result}
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
          @order.weight_oz != params[:order]['weight_oz']
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

    @result['orders'] = make_orders_list(@orders)
    @result['orders_count'] = get_orders_count()

    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def duplicateorder

    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
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
            @result['messages'] = @neworder.errors.full_messages
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
      @result['messages'].push("You do not have enough permissions to duplicate order")
    end

    respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
    end
  end

  def deleteorder
    @result = Hash.new
    @result['status'] = true
    @result['messages'] = []
    @orders = list_selected_orders
    if current_user.can? 'add_edit_order_items'
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
    else
      @result['status'] = false
      @result['messages'].push("You do not have enough permissions to delete order")
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
      @result['orders_count'] = get_orders_count()      
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
    @result['messages'] = []

    @orders = list_selected_orders
    if current_user.can? 'change_order_status'
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
    else
      @result['status'] = false
      @result['messages'].push("You do not have enough permissions to delete order")
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
            @orderitem['sku'] = product.product_skus.order('product_skus.order ASC').first.sku
          end
          @orderitem['productimages'] = product.product_images.order("product_images.order ASC")

        end
        @result['order']['items'].push(@orderitem)
      end
      @result['order']['storeinfo'] = @order.store

      #setting user permissions for add and remove items permitted
      @result['order']['add_items_permitted'] = current_user.can? 'add_edit_order_items'
      @result['order']['remove_items_permitted'] = current_user.can? 'add_edit_order_items'
      @result['order']['activities'] = @order.order_activities

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
            @order.addactivity("Item with sku " + product_sku + " added", username)
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
            item.order.addactivity("Item with sku " + sku + " removed", username)
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
          arr = params[:value].blank? ? [] : params[:value].split(" ")
          @order.lastname = arr.pop()
          @order.firstname = arr.join(" ")
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
            @result['error_msg'] = "Could not save order info"
          end
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

    respond_to do |format|
      format.html
      format.json {
        result['data']['pick_list'] = @pick_list
        result['data']['depends_pick_list'] = @depends_pick_list
        time = Time.now
        file_name = 'pick_list_'+time.strftime("%d_%b_%Y")
        result['data']['pick_list_file_paths'] = '/pdfs/'+ file_name + '.pdf'
        render :pdf => file_name, 
        :template => 'orders/generate_pick_list',
        :orientation => 'portrait',
        :page_height => '8in', 
        :save_only => true,
        :page_width => '11.5in',
        :margin => {:top => '20',                     
                    :bottom => '20',
                    :left => '0',
                    :right => '0'},
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

    if @orientation == "landscape"
      @page_height = @page_height.to_f/2
      @page_height = @page_height.to_s
    end
    @header = ""
    @footer = ""
    time = Time.now
    @file_name = time.strftime("%d_%b_%Y_%I:%M_%p")
    @orders = list_selected_orders
    packing_slip_obj = 
          Groovepacker::PackingSlip::PdfMerger.new 
    unless @orders.nil?
      @orders.each do|order|
        @order = Order.find(order['id'])

        generate_pdf(@result,@order,@page_height,@page_width,@orientation,@file_name,@header,@footer)

        reader = PDF::Reader.new(Rails.root.join('public', 'pdfs', "#{@order.increment_id}.pdf"))
        page_count = reader.page_count

        #delete the file
        File.delete(Rails.root.join('public', 'pdfs', @order.increment_id+".pdf"))
        
        if page_count > 1
          @header = "Multi-Slip Order # " + @order.increment_id
          @footer = "Multi-Slip Order # " + @order.increment_id
        else
          @header = ""
          @footer = ""
        end
        generate_pdf(@result,@order,@page_height,@page_width,@orientation,@file_name,@header,@footer)
         
        @result['data']['packing_slip_file_paths'].push(Rails.root.join('public','pdfs', "#{@order.increment_id}.pdf"))

      end
      @result['data']['destination'] =  Rails.root.join('public','pdfs', "#{@file_name}_packing_slip.pdf")
      @result['data']['merged_packing_slip_url'] =  '/pdfs/'+ @file_name + '_packing_slip.pdf'
      
      #merge the packing-slips
      packing_slip_obj.merge(@result,@orientation,@size,@file_name)
      
      render json: @result        
    end
  end
  
  def import_all
    # import_orders_helper()

    result = Hash.new
    result['success_messages'] = []
    result['error_messages'] = []
    order_summary = OrderImportSummary.where(
      status: 'in_progress')

    if order_summary.empty?
      order_summary_info = OrderImportSummary.new
      order_summary_info.user_id = current_user.id
      order_summary_info.status = 'not_started'
      order_summary_info.save
      # call delayed job
      tenant = Apartment::Tenant.current_tenant
      import_orders_obj = ImportOrders.new
      Delayed::Job.where(queue: "importing_orders_#{tenant}").destroy_all
      import_orders_obj.delay(:run_at => 1.seconds.from_now,:queue => "importing_orders_#{tenant}").import_orders  tenant    # import_orders_obj.import_orders
    else
      #Send a message back to the user saying that import is already in progress
      result['error_messages'].push('Import is in progress')
    end
    render json: "ok"
  end

  def import_status
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new

    order_import_summaries = OrderImportSummary.order('updated_at' + " " + 'desc')
    if !order_import_summaries.empty?
      order_import_summary = order_import_summaries.first
      result['data']['import_summary'] = Hash.new
      if !order_import_summary.nil?
        result['data']['import_summary']['import_info'] = order_import_summary
        result['data']['import_summary']['import_items'] = []
        order_import_summary.import_items.each do |import_item|
          result['data']['import_summary']['import_items'].push(
            {store_info: import_item.store, import_info: import_item})
        end
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

  def generate_pdf(result,order,page_height,page_width,orientation,file_name,header,footer)
    respond_to do |format|
      format.json{
        render :pdf => file_name, 
                :template => 'orders/generate_packing_slip.html.erb',
                :orientation => @orientation,
                :page_height => @page_height+'in', 
                :page_width => @page_width+'in',
                :save_only => true,
                :no_background => false,
                :margin => {:top => '5',                     
                            :bottom => '10',
                            :left => '2',
                            :right => '2'},
                :header => {
                  :html => { 
                    :template => 'orders/generate_packing_slip_header.pdf.erb'
                    }
                },
                :footer => {
                  :html => { 
                    :template => 'orders/generate_packing_slip_header.pdf.erb'
                    }
                },
                :save_to_file => Rails.root.join('public', 'pdfs', "#{order.increment_id}.pdf")
      }
    end
  end

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

  def get_orders_count
    count = Hash.new
    count['all'] = Order.all.count
    count['scanned'] = Order.where(:status => 'scanned').count
    count['cancelled'] = Order.where(:status => 'cancelled').count
    count['onhold'] = Order.where(:status => 'onhold').count
    count['awaiting'] = Order.where(:status => 'awaiting').count
    count['serviceissue'] = 
      Order.where(:status => 'serviceissue').count

    count
  end




end
