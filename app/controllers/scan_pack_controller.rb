class ScanPackController < ApplicationController
	before_filter :authenticate_user!
  	include ScanPackHelper
	#input is barcode which is increment_id in the orders table
	def scan_order_by_barcode
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = []
	    @result['notice_messages'] = []

	    if !params[:barcode].nil? && params[:barcode] != ""
		    @order = Order.where(:increment_id=>params[:barcode])

		    if @order.length > 0
		    	@order = @order.first
		    	@order_result = Hash.new

          @order_result['status'] = @order.status
          @order_result["id"] = @order.id

            #search in orders that have status of Scanned
          if @order.status == 'scanned'
            @order_result['scanned_on'] = @order.scanned_on
            @order_result['next_state'] = 'ready_for_order'
            @result['notice_messages'].push('This order has already been scanned')
          end

          #search in orders that have status of On Hold
          if @order.status == 'onhold'
            if @order.has_inactive_or_new_products
              #get list of inactive_or_new_products
              @order_result['next_state'] = 'request_for_confirmation_code_with_product_edit'
              @result['notice_messages'].push("The following items in this order are not Active."+
                "They may need a barcode or other product info before their status can be changed"+
                " to Active")
            else
              @order_result['order_edit_permission'] = current_user.import_orders
              @order_result['next_state'] = 'request_for_confirmation_code_with_order_edit'
              @result['notice_messages'].push('This order is currently on Hold. Please scan or enter '+
                  'confirmation code with order edit permission to continue scanning this order or '+
                  'scan a different order')
            end
          end



            #search in orders that have status of Cancelled
          if @order.status == 'cancelled'
            @order_result['next_state'] = 'ready_for_order'
            @result['notice_messages'].push('This order has been cancelled')
          end

          #if order has status of Awaiting Scanning
          if @order.status == 'awaiting'
            @order_result['next_state'] = 'ready_for_product'
			@order_result['unscanned_items'] = @order.get_unscanned_items
			@order_result['scanned_items'] = @order.get_scanned_items
          end
		    else
		    	@result['notice_messages'].push('This order cannot be found. It may not have been imported yet')
		    end
		  else
			  @result['status'] &= false
			  @result['error_messages'].push("Please specify a barcode to scan the order")
      end
    @result['data'] = @order_result

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
	end
	# input is confirmation_code and order_id no.
	def order_edit_confirmation_code
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = []
	    @result['notice_messages'] = []
	    @result['data'] = Hash.new

	    if !params[:order_id].nil? || !params[:confirmation_code].nil?
			#check if order status is On Hold
			@order = Order.find(params[:order_id])
			if !@order.nil?
				if @order.status == "onhold" && !@order.has_inactive_or_new_products
					if User.where(:confirmation_code => params[:confirmation_code]).length > 0
						@result['data']['order_edit_matched'] = true
						@order.status = 'awaiting'
						@order.addactivity("Status changed from onhold to awaiting",
							User.where(:confirmation_code => params[:confirmation_code]).first.username)
						@order.save
				 		@result['data']['scanned_on'] = @order.scanned_on
				 		@result['data']['next_state'] = 'ready_for_product'
						@result['unscanned_items'] = @order.get_unscanned_items
						@result['scanned_items'] = @order.get_scanned_items
						session[:order_edit_matched_for_current_user] = true
					else
						@result['data']['order_edit_matched'] = false
						@result['data']['next_state'] = 'request_for_confirmation_code_with_order_edit'
					end
				else
					@result['status'] &= false
					@result['error_messages'].push("Only orders with status On Hold and has inactive or new products "+
						"can use edit confirmation code.")
				end
			else
				@result['status'] &= false
				@result['error_messages'].push("Could not find order with id:"+params[:order_id])
			end

			#check if current user edit confirmation code is same as that entered
	    else
			@result['status'] &= false
			@result['error_messages'].push("Please specify confirmation code and order id to confirm purchase code")
	    end

	    respond_to do |format|
	      format.html # show.html.erb
	      format.json { render json: @result }
	    end
	end

	def product_edit_confirmation_code
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = []
	    @result['notice_messages'] = []
	    @result['data'] = Hash.new

	    if !params[:order_id].nil? || !params[:confirmation_code].nil?
			#check if order status is On Hold
			@order = Order.find(params[:order_id])
			if !@order.nil?
				if @order.status == "onhold" && @order.has_inactive_or_new_products
					if User.where(:confirmation_code => params[:confirmation_code]).length > 0
						@result['data']['product_edit_matched'] = true
						@result['data']['inactive_or_new_products'] = @order.get_inactive_or_new_products
				 		@result['data']['next_state'] = 'product_edit'
						session[:product_edit_matched_for_current_user] = true
					else
						@result['data']['product_edit_matched'] = false
						@result['data']['next_state'] = 'request_for_confirmation_code_with_product_edit'
					end
				else
					@result['status'] &= false
					@result['error_messages'].push("Only orders with status On Hold and has inactive or new products "+
						"can use edit confirmation code.")
				end
			else
				@result['status'] &= false
				@result['error_messages'].push("Could not find order with id:"+params[:order_id])
			end

			#check if current user edit confirmation code is same as that entered
	    else
			@result['status'] &= false
			@result['error_messages'].push("Please specify confirmation code and order id to confirm purchase code")
	    end

	    respond_to do |format|
	      format.html # show.html.erb
	      format.json { render json: @result }
	    end
  end

  def inactive_or_new
    @result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new

    if params[:order_id].nil?
      @result['status'] &= false
      @result['error_messages'].push("Please specify order id")
    else
      @order = Order.find_by_id(params[:order_id])
      if @order.nil?
        @result['status'] &= false
        @result['error_messages'].push("Could not find order with id:"+params[:order_id])
      elsif @order.has_inactive_or_new_products
        @result['data']['inactive_or_new_products'] = @order.get_inactive_or_new_products
        @result['data']['next_state'] = 'product_edit'
      else
        @result['data']['inactive_or_new_products'] = []
        @result['data']['next_state'] = 'order_clicked'
        @result['data']['barcode'] = @order.increment_id
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
  end

	#input is barcode, order id
	def scan_product_by_barcode
	@result = Hash.new
    @result['status'] = true
    @result['error_messages'] = []
    @result['success_messages'] = []
    @result['notice_messages'] = []
    @result['data'] = Hash.new
    @result['data']['next_state'] = 'ready_for_product'

    if !params[:order_id].nil? || !params[:barcode].nil?
			#check if order status is On Hold
			@order = Order.find(params[:order_id])
			if !@order.nil?
				if @order.has_unscanned_items
					if @order.contains_kit && @order.contains_splittable_kit
						puts "order contains kit"
						#if order contains a kit which is to be Scanned as either Kit or individual parts as needed
							puts "order contains splittable kit"
					  	#check if due to current barcode the kit needs to be split or not
						if @order.should_the_kit_be_split(params[:barcode])
							puts "kit should be split"
							#@order.mark_order_item_kit_to_be_split
						  	#if it needs to be split, then mark split as 1 in the order item
						  	 #get scanned products and to be scanned products
						  	#end
					   else
					    #process the barcode scan
					    #get scanned products and to be scanned products based on whether the kit is split or not
					   end
					else
					  unscanned_items = @order.get_unscanned_items
					  barcode_found = false
					  #puts unscanned_items.to_s
					  #search if barcode exists
					  unscanned_items.each do |item|
					  	if item['product_type'] == 'individual'
					  		if item['child_items'].length > 0
						  		item['child_items'].each do |child_item|
						  			#puts child_item.to_s
						  			if !child_item['barcodes'].nil?
							  			child_item['barcodes'].each do |barcode|
							  				if barcode.barcode == params[:barcode]
							  					barcode_found = true
							  					#process product barcode scan
							  					order_item_kit_product = 
							  						OrderItemKitProduct.find(child_item['kit_product_id'])
							  					order_item_kit_product.process_item if !order_item_kit_product.nil?
							  					break
							  				end
							  			end
						  			end
						  			break if barcode_found
						  		end
					  		end
					  	elsif item['product_type'] == 'single'
							item['barcodes'].each do |barcode|
				  				if barcode.barcode == params[:barcode]
				  					barcode_found = true
				  					#process product barcode scan
				  					order_item = OrderItem.find(item['order_item_id'])
				  					order_item.process_item if !order_item.nil?
				  					break
				  				end
					  		end
					  	end
					  	break if barcode_found
					  end
					  #puts "Barcode "+params[:barcode]+" found: "+barcode_found.to_s
					  if barcode_found
					  	@order.reload
					  	@result['data']['unscanned_items'] = @order.get_unscanned_items
					  	@result['data']['scanned_items'] = @order.get_scanned_items
					  	#puts "Length of unscanned items:" + @result['data']['unscanned_items'].length.to_s
					  	#puts @result['data']['unscanned_items'].to_s
					  else
						@result['status'] &= false
						@result['error_messages'].push("No matching barcode found for this order")
					  end
					end
				else
					@result['status'] &= false
					@result['error_messages'].push("There are no unscanned items in this order")
				end
			else
				@result['status'] &= false
				@result['error_messages'].push("Could not find order with id:"+params[:order_id])
			end
	else
		@result['status'] &= false
		@result['error_messages'].push("Please specify barcode and order id to confirm purchase code")
	end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @result }
    end
	end
end
