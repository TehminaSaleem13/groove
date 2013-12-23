class ScanPackController < ApplicationController
	before_filter :authenticate_user!

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
					barcode_found = false
					@order.order_items.each do |order_item|
            product = Product.find_by_id(order_item.product_id)
						unless product.nil?
              barcodes = product.product_barcodes.where(:barcode=>params[:barcode])
              if barcodes.length > 0
                barcode_found = true

                if order_item.scanned_status == 'scanned' || order_item.scanned_qty >= order_item.qty
                  @result['status'] &= false
                  @result['error_messages'].push("This item has already been scanned, Please scan another item")
                else
                  order_item.scanned_qty = order_item.scanned_qty + 1
                  if order_item.scanned_qty == order_item.qty
                    order_item.scanned_status = 'scanned'
                  else
                    order_item.scanned_status = 'partially_scanned'
                  end
                  order_item.save
                end
                unless @order.has_unscanned_items
                   @order.set_order_to_scanned_state
                   @result['data']['next_state'] = 'ready_for_order'
                end
                break
              end
						end
					end
					unless barcode_found
						@result['status'] &= false
						@result['error_messages'].push("There are no barcodes that match items in this order")
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
