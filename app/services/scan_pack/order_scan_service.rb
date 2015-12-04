module ScanPack
  class OrderScanService < ScanPack::Base
    def initialize(current_user, session, input, state, id)
      @current_user = current_user
      @input = input
      @state = state
      @id = id
      @result = {
        "status" => true,
        "matched" => true,
        "error_messages" => [],
        "success_messages" => [],
        "notice_messages" => [],
        "data" => {
          "next_state" => "scanpack.rfo"
          }
      }
      @orders = []
      @scanpack_settings = ScanPackSetting.all.first
      @session = session.merge({
        most_recent_scanned_products: [],
        parent_order_item: false
      })
    end

    def run
      check_validity? ? order_scan : (return @result)
      @result
    end

    def check_validity?
      validity = @input && @input != ""
      unless validity
        @result['status'] &= false
        @result['error_messages'].push("Please specify a barcode to scan the order")
      end
      validity
    end

    def collect_orders
      @orders = Order.where(['increment_id = ? or non_hyphen_increment_id =?', @input, @input])
      if @orders.length == 0 && @scanpack_settings.scan_by_tracking_number
        @orders = Order.where(
          'tracking_num = ? or ? LIKE CONCAT("%",tracking_num,"%") ',
          @input, @input)
      end
    end

    def order_scan
      collect_orders
      single_order = nil
      single_order_result = Hash.new
      single_order_result['matched_orders'] = []

      if @orders.length == 1
        single_order = @orders.first
      else
        @orders.each do |matched_single|
          if single_order.nil?
            single_order = matched_single
          elsif matched_single.status == 'awaiting' &&
            (single_order.status != 'awaiting' || single_order.order_placed_time < matched_single.order_placed_time)
            single_order = matched_single
          elsif matched_single.status == 'onhold' && single_order.status != 'awaiting' &&
            (single_order.status != 'onhold' || single_order.order_placed_time < matched_single.order_placed_time)
            single_order = matched_single
          elsif matched_single.status == 'serviceissue' && single_order.status != 'awaiting' && single_order.status != 'onhold' &&
            (single_order.status != 'serviceissue' || single_order.order_placed_time < matched_single.order_placed_time)
            single_order = matched_single
          end
          unless ['scanned', 'cancelled'].include?(matched_single.status)
            single_order_result['matched_orders'].push(matched_single)
          end
        end
      end

      if single_order.nil?
        if @scanpack_settings.scan_by_tracking_number
          @result['notice_messages'].push('Order with tracking number '+
                                           @input +' cannot be found. It may not have been imported yet')
        else
          @result['notice_messages'].push('Order with number '+
                                           @input +' cannot be found. It may not have been imported yet')
        end
      else
        single_order_result['status'] = single_order.status
        single_order_result['order_num'] = single_order.increment_id

        #can order be scanned?
        if can_order_be_scanned
          unless single_order.status == 'scanned'
            single_order.packing_user_id = @current_user.id
            single_order.save
          end
          #search in orders that have status of Scanned
          if single_order.status == 'scanned'
            single_order_result['scanned_on'] = single_order.scanned_on
            single_order_result['next_state'] = 'scanpack.rfo'
            @result['notice_messages'].push('This order has already been scanned')
          end

          #search in orders that have status of On Hold
          if single_order.status == 'onhold'
            if single_order.has_inactive_or_new_products
              #get list of inactive_or_new_products
              single_order_result['conf_code'] = @session[:confirmation_code]

              if @current_user.can?('add_edit_products') || (@session[:product_edit_matched_for_current_user] && @session[:product_edit_matched_for_order] == single_order.id)
                single_order_result['product_edit_matched'] = true
                single_order_result['inactive_or_new_products'] = single_order.get_inactive_or_new_products
                single_order_result['next_state'] = 'scanpack.rfp.product_edit'
              else
                @session[:product_edit_matched_for_current_user] = false
                @session[:order_edit_matched_for_current_user] = false
                @session[:product_edit_matched_for_order] = false
                @session[:product_edit_matched_for_products] = []
                single_order_result['next_state'] = 'scanpack.rfp.confirmation.product_edit'
                @result['notice_messages'].push("This order was automatically placed on hold because it contains items that have a "+
                                                 "status of New or Inactive. These items may not have barcodes or other information needed for processing. "+
                                                 "Please ask a user with product edit permissions to scan their code so that these items can be edited or scan a different order.")
              end
            else
              single_order_result['order_edit_permission'] = @current_user.can?('import_orders')
              single_order_result['next_state'] = 'scanpack.rfp.confirmation.order_edit'
              @result['notice_messages'].push('This order is currently on Hold. Please scan or enter '+
                                               'confirmation code with order edit permission to continue scanning this order or '+
                                               'scan a different order.')
            end
          end

          #process orders that have status of Service Issue
          if single_order.status == 'serviceissue'
            single_order_result['next_state'] = 'scanpack.rfp.confirmation.cos'
            if @current_user.can?('change_order_status')
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
          if single_order.status == 'cancelled'
            single_order_result['next_state'] = 'scanpack.rfo'
            @result['notice_messages'].push('This order has been cancelled')
          end

          #if order has status of Awaiting Scanning
          if single_order.status == 'awaiting'
            if !single_order.has_unscanned_items
              if @scanpack_settings.post_scanning_option != "None"
                if @scanpack_settings.post_scanning_option == "Verify"
                  if single_order.tracking_num.nil?
                    single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
                    single_order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", @current_user.username)
                  else
                    single_order_result['next_state'] = 'scanpack.rfp.verifying'
                  end
                elsif @scanpack_settings.post_scanning_option == "Record"
                  single_order_result['next_state'] = 'scanpack.rfp.recording'
                elsif @scanpack_settings.post_scanning_option == "PackingSlip"
                  #generate packingslip for the order
                  single_order.set_order_to_scanned_state(@current_user.username)
                  single_order_result['next_state'] = 'scanpack.rfo'
                  generate_packing_slip(single_order)
                else
                  #generate barcode for the order
                  single_order.set_order_to_scanned_state(@current_user.username)
                  single_order_result['next_state'] = 'scanpack.rfo'
                  generate_order_barcode_slip(single_order)
                end
              else
                single_order.set_order_to_scanned_state(@current_user.username)
                single_order_result['next_state'] = 'scanpack.rfo'
              end
            else
              single_order_result['next_state'] = 'scanpack.rfp.default'
              single_order.last_suggested_at = DateTime.now
              single_order.scan_start_time = DateTime.now if single_order.scan_start_time.nil?
            end
          end
          unless single_order.nil?
            unless single_order.save
              @result['status'] &= false
              @result['error_messages'].push("Could not save order with id: "+single_order.id)
            end
            single_order_result['order'] = order_details_and_next_item(single_order)
          end
        else
          @result['status'] &= false
          @result['error_messages'].push("You have reached the maximum limit of number of shipments for your subscription.")
          single_order_result['next_state'] = 'scanpack.rfo'
        end
        @result['data'] = single_order_result
        @result['data']['scan_pack_settings'] = @scanpack_settings
      end
    end
  end
end