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
	    session[:most_recent_scanned_products] = []
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
              @order_result['conf_code'] = session[:confirmation_code]

          	  if current_user.edit_products
				@order_result['product_edit_matched'] = true
				@order_result['inactive_or_new_products'] = @order.get_inactive_or_new_products
		 		@order_result['next_state'] = 'product_edit'
              else
                @order_result['next_state'] = 'request_for_confirmation_code_with_product_edit'
                @result['notice_messages'].push("This order was automatically placed on hold because it contains items that have a "+
                	"status of New or Inactive. These items may not have barcodes or other information needed for processing. "+
                	"Please ask a user with product edit permissions to scan their code so that these items can be edited or scan a different order.")
              end
            else
              @order_result['order_edit_permission'] = current_user.import_orders
              @order_result['next_state'] = 'request_for_confirmation_code_with_order_edit'
              @result['notice_messages'].push('This order is currently on Hold. Please scan or enter '+
                  'confirmation code with order edit permission to continue scanning this order or '+
                  'scan a different order.')
            end
          end
          
          #process orders that have status of Service Issue
          if @order.status == 'serviceissue'
          	@order_result['next_state'] = 'request_for_confirmation_code_with_cos'
          	if current_user.change_order_status
            	@result['notice_messages'].push('This order has a pending Service Issue. '+
            		'To clear the Service Issue and continue packing the order please scan your confirmation code or scan a different order.')
            else
            	@result['notice_messages'].push('This order has a pending Service Issue. To continue with this order, '+
            		'please ask another user who has Change Order Status permissions to scan their '+
            	 	'confirmation code and clear the issue. Alternatively, you can pack another order '+
            	 	'by scanning another order number.')
            end
          end

           #search in orders that have status of Cancelled
          if @order.status == 'cancelled'
            @order_result['next_state'] = 'ready_for_order'
            @result['notice_messages'].push('This order has been cancelled')
          end

          #if order has status of Awaiting Scanning
          if @order.status == 'awaiting'
		  	if !@order.has_unscanned_items
		  		@order_result['next_state'] = 'ready_for_tracking_num'
		  	else
	            @order_result['next_state'] = 'ready_for_product'
				@order_result['unscanned_items'] = @order.get_unscanned_items
				@order_result['scanned_items'] = @order.get_scanned_items
			end
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
						user = User.where(:confirmation_code => params[:confirmation_code]).first
						if user.edit_products
							@result['data']['product_edit_matched'] = true
							@result['data']['inactive_or_new_products'] = @order.get_inactive_or_new_products
					 		@result['data']['next_state'] = 'product_edit'
							session[:product_edit_matched_for_current_user] = true
						else
							@result['data']['product_edit_matched'] = false
							@result['data']['next_state'] = 'request_for_confirmation_code_with_product_edit'
							@result['error_messages'].push("User with confirmation code "+ params[:confirmation_code] +
								"does not have permission for editing products.")
						end
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
					kit_split = false
					if @order.contains_kit && @order.contains_splittable_kit
						#puts "order contains kit"
						#if order contains a kit which is to be Scanned as either Kit or individual parts as needed
						#puts "order contains splittable kit"
					  	#check if due to current barcode the kit needs to be split or not
						if @order.should_the_kit_be_split(params[:barcode])
							#puts "kit should be split"
							#kit_split = true
							#unscanned_items = @order.get_unscanned_split_item
					   end
					end
					if !kit_split
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
				  					(session[:most_recent_scanned_products] ||= []) << order_item.product_id
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
					  	@result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
					  	
					  	next_item_found = false
					  	@result['data']['next_item_present'] = false
					  	session[:most_recent_scanned_products].reverse!.each do |scanned_product_id|
					  		@result['data']['unscanned_items'].each do |unscanned_item|
					  			if scanned_product_id == unscanned_item['product_id'] && 
					  				unscanned_item['scanned_qty'] + unscanned_item['qty_remaining'] > 0
					  				@result['data']['next_item'] = Hash.new
					  				@result['data']['next_item']['name'] = unscanned_item['name']
					  				@result['data']['next_item']['sku'] = unscanned_item['sku']
					  				@result['data']['next_item']['images'] = unscanned_item['images']
					  				@result['data']['next_item']['scanned_qty'] = unscanned_item['scanned_qty']
					  				@result['data']['next_item']['qty'] = unscanned_item['scanned_qty'] +
					  					unscanned_item['qty_remaining']
					  				@result['data']['next_item']['qty_remaining'] = unscanned_item['qty_remaining']
					  				@result['data']['next_item_present'] = true
					  				next_item_found = true
					  				break
					  			end
					  		end
					  		break if next_item_found
					  	end

					  	if !@order.has_unscanned_items
					  		@result['data']['next_state'] = 'ready_for_tracking_num'
					  	end
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
	# takes order_id as input and resets scan status if it is partially scanned.
	def reset_order_scan
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = []
	    @result['notice_messages'] = []
	    @result['data'] = Hash.new
	    
	   	@order = Order.find(params[:order_id])

	   	if !@order.nil?
	   		if @order.status != 'scanned'
		   		@order.reset_scanned_status
		    	@result['data']['next_state'] = 'ready_for_order'
		    else
				@result['status'] &= false
				@result['error_messages'].push("Order with id: "+params[:order_id]+" is already in scanned state")
		    end
	   	else
			@result['status'] &= false
			@result['error_messages'].push("Could not find order with id: "+params[:order_id])
	   	end

	    respond_to do |format|
	      format.html # show.html.erb
	      format.json { render json: @result }
	    end
	end

	# takes order_id and tracking number as input.
	def scan_tracking_num
		result = Hash.new
	    result['status'] = true
	    result['error_messages'] = []
	    result['success_messages'] = []
	    result['notice_messages'] = []
	    result['data'] = Hash.new
	    
	   	order = Order.find(params[:order_id])

	   	if !order.nil? 
	   		if order.status == 'awaiting'
		   		if !params[:tracking_num].nil?
			   		order.tracking_num =  params[:tracking_num]
			   		order.set_order_to_scanned_state(current_user.username)
			   		#update inventory when inventory warehouses is implemented.
			   		order.save
			    else
					result['status'] &= false
					result['error_messages'].push("No tracking number is provided")
			    end
			else
				result['status'] &= false
				result['error_messages'].push("The order is not in awaiting state. Cannot scan the tracking number")
			end
	   	else
			result['status'] &= false
			result['error_messages'].push("Could not find order with id: "+params[:order_id])
	   	end

	    respond_to do |format|
	      format.html # show.html.erb
	      format.json { render json: result }
	    end
	end

	def cos_confirmation_code
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = []
	    @result['notice_messages'] = []
	    @result['data'] = Hash.new

	    if !params[:order_id].nil? || !params[:cos_confirmation_code].nil?
			#check if order status is On Hold
			@order = Order.find(params[:order_id])
			if !@order.nil?
				if @order.status == "serviceissue"
					if User.where(:confirmation_code => params[:cos_confirmation_code]).length > 0
						user = User.where(:confirmation_code => params[:cos_confirmation_code]).first

						if user.change_order_status
							@result['data']['cos_confirmation_code_matched'] = true
							#set order state to awaiting scannus
							@order.status = 'awaiting'
							@order.save
							@order.update_order_status
							#set next state 
					 		@result['data']['next_state'] = 'ready_for_order'
				 		else
							@result['data']['cos_confirmation_code_matched'] = false
							@result['data']['next_state'] = 'request_for_confirmation_code_with_cos'
							@result['error_messages'].push("User with confirmation code: "+ params[:cos_confirmation_code]+ " does not have permission to change order status")
				 		end
					else
						@result['data']['cos_confirmation_code_matched'] = false
						@result['data']['next_state'] = 'request_for_confirmation_code_with_cos'
						@result['error_messages'].push("Could not find any user with confirmation code")
					end
				else
					@result['status'] &= false
					@result['error_messages'].push("Only orders with status Service issue"+
						"can use change of status confirmation code")
				end
			else
				@result['status'] &= false
				@result['error_messages'].push("Could not find order with id:"+params[:order_id])
			end

			#check if current user edit confirmation code is same as that entered
	    else
			@result['status'] &= false
			@result['error_messages'].push("Please specify confirmation code and order id to change order status")
	    end

	    respond_to do |format|
	      format.html # show.html.erb
	      format.json { render json: @result }
	    end
	end
end
