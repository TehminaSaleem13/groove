class ScanPackController < ApplicationController
	before_filter :authenticate_user!

	#input is barcode which is increment_id in the orders table
	def scan_order_by_barcode
		@result = Hash.new
	    @result['status'] = true
	    @result['error_messages'] = []
	    @result['success_messages'] = [] 
	    @result['notice_messages'] = []

	    if !params[:barcode].nil?
		    @order = Order.where(:increment_id=>params[:barcode])

		    if @order.length > 0
		    	@order = @order.first
		    	@order_result = Hash.new
			 	@order_result['status'] = @order.status
			  	
			  	#search in orders that have status of Scanned
			 	if @order.status == 'Scanned'
			 		@order_result['scanned_on'] = @order.scanned_on
			 		@order_result['next_state'] = 'ready_for_order'
			 		@result['notice_messages'].push('This order has already been scanned')
			 	end


				#search in orders that have status of On Hold


			  	#search in orders that have status of Cancelled
			 	if @order.status == 'Cancelled'
			 		@order_result['next_state'] = 'ready_for_order'
			 		@result['notice_messages'].push('This order has been cancelled')
			 	end

			 	#if order has status of Awaiting Scanning
			 	if @order.status == 'Awaiting Scanning'
			 		@order.set_order_to_scanned_state
			 		@order_result['scanned_on'] = @order.scanned_on
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

	# def method_name
		
	# end
end
