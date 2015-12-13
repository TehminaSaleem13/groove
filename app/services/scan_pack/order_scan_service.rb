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
      @single_order = nil
      @single_order_result = { 'matched_orders' => [] }
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

    def order_scan
      collect_orders
      @single_order, @single_order_result = get_single_order_with_result
      do_if_single_order_not_present and return unless @single_order.present?
      do_if_single_order_present
    end

    def collect_orders
      @orders = Order.where(['increment_id = ? or non_hyphen_increment_id =?', @input, @input])
      if @orders.length == 0 && @scanpack_settings.scan_by_tracking_number
        @orders = Order.where(
          'tracking_num = ? or ? LIKE CONCAT("%",tracking_num,"%") ',
          @input, @input)
      end
    end

    def get_single_order_with_result
      # assign @single_order = first order for only one order
      return [@orders.first, @single_order_result] if @orders.length == 1
      
      @orders.each do |matched_single|
        matched_single_status = matched_single.status
        matched_single_order_placed_time = matched_single.order_placed_time
        single_order_status = @single_order.status
        single_order_order_placed_time = @single_order.order_placed_time
        order_placed_for_single_before_than_matched_single = single_order_order_placed_time < matched_single_order_placed_time
        
        @single_order ||= matched_single

        do_check_order_status_for_single_and_matched(
          single_order_status, matched_single_status, order_placed_for_single_before_than_matched_single
          ) if single_order.present?

        unless ['scanned', 'cancelled'].include?(matched_single_status)
          @single_order_result['matched_orders'].push(matched_single)
        end
      end

      return [@single_order, @single_order_result]
    end

    def do_check_order_status_for_single_and_matched(
                       matched_single, single_order_status, matched_single_status,
                       order_placed_for_single_before_than_matched_single
                        )
      %w(awaiting onhold serviceissue).each do |status|
        prev_states = []
        if matched_single_status == status && !single_order_status.in?(prev_states) && (
            single_order_status != status || order_placed_for_single_before_than_matched_single
          )
          @single_order = matched_single
          break
        else
          prev_states.push(status)
        end
      end
    end

    def do_if_single_order_not_present
      message = if @scanpack_settings.scan_by_tracking_number
        'Order with tracking number '+ @input +
        ' cannot be found. It may not have been imported yet'
      else
        'Order with number '+ @input +
        ' cannot be found. It may not have been imported yet'
      end
      @result['notice_messages'].push(message)
    end

    def do_if_single_order_present
      @single_order_result['status'] = @single_order.status
      @single_order_result['order_num'] = @single_order.increment_id

      if can_order_be_scanned
        do_if_under_max_limit_of_shipments
      else
        @result['status'] &= false
        @result['error_messages'].push(
          "You have reached the maximum limit of number of shipments for your subscription."
          )
        @single_order_result['next_state'] = 'scanpack.rfo'
      end
      @result['data'] = @single_order_result
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end

    def do_if_under_max_limit_of_shipments
      single_order_status = @single_order.status

      unless single_order_status == 'scanned'
        @single_order.packing_user_id = @current_user.id
        @single_order.save
      end

      #PROCESS based on Order Status
      #-----------------------------
      #search in orders that have status of Scanned
      do_if_already_been_scanned if single_order_status.eql?('scanned')
      do_if_single_order_status_on_hold if single_order_status.eql?('onhold')
      #process orders that have status of Service Issue
      do_if_single_order_status_serviceissue if single_order_status.eql?('serviceissue')
      #search in orders that have status of Cancelled
      do_if_single_order_status_cancelled if single_order_status.eql?('cancelled')
      #if order has status of Awaiting Scanning
      do_if_single_order_status_awaiting if single_order_status.eql?('awaiting')
      #----------------------------

      do_if_single_order_present_and_under_max_limit_of_shipment if @single_order.present?
    end

    def do_if_single_order_present_and_under_max_limit_of_shipment
      unless @single_order.save
        @result['status'] &= false
        @result['error_messages'].push("Could not save order with id: "+@single_order.id)
      end
      @single_order_result['order'] = order_details_and_next_item
    end

    def do_if_already_been_scanned
      @single_order_result['scanned_on'] = @single_order.scanned_on
      @single_order_result['next_state'] = 'scanpack.rfo'
      @result['notice_messages'].push('This order has already been scanned')
    end

    def do_if_single_order_status_on_hold
      message = nil
      if @single_order.has_inactive_or_new_products
        #get list of inactive_or_new_products
        @single_order_result['conf_code'] = @session[:confirmation_code]

        if @current_user.can?('add_edit_products') || (
            @session[:product_edit_matched_for_current_user] &&
            @session[:product_edit_matched_for_order] == @single_order.id
            )
          @single_order_result.merge!({
              'product_edit_matched' => true,
              'inactive_or_new_products' => @single_order.get_inactive_or_new_products,
              'next_state' => 'scanpack.rfp.product_edit'
            })
        else
          @session.merge!({
            product_edit_matched_for_current_user: false,
            order_edit_matched_for_current_user: false,
            product_edit_matched_for_order: false,
            product_edit_matched_for_products: []
            })
          @single_order_result['next_state'] = 'scanpack.rfp.confirmation.product_edit'
          message = 'This order was automatically placed on hold because it '\
            'contains items that have a status of New or Inactive. These items '\
            'may not have barcodes or other information needed for processing. '\
            'Please ask a user with product edit permissions to scan their code'\
            ' so that these items can be edited or scan a different order.'
        end
      else
        @single_order_result['order_edit_permission'] = @current_user.can?('import_orders')
        @single_order_result['next_state'] = 'scanpack.rfp.confirmation.order_edit'
        message = 'This order is currently on Hold. Please scan or enter '\
         'confirmation code with order edit permission to continue scanning '\
         'this order or scan a different order.'
      end
      @result['notice_messages'].push(message)
    end

    def do_if_single_order_status_serviceissue
      @single_order_result['next_state'] = 'scanpack.rfp.confirmation.cos'
      message = if @current_user.can?('change_order_status')
        'This order has a pending Service Issue. '\
        'To clear the Service Issue and continue packing the order '\
        'please scan your confirmation code or scan a different order.'
      else
        'This order has a pending Service Issue. To continue with this order, '\
        'please ask another user who has Change Order Status permissions to '\
        'scan their confirmation code and clear the issue. Alternatively, you '\
        'can pack another order by scanning another order number.'
      end
      @result['notice_messages'].push(message)
    end

    def do_if_single_order_status_cancelled
      @single_order_result['next_state'] = 'scanpack.rfo'
      @result['notice_messages'].push('This order has been cancelled')
    end

    def do_if_single_order_status_awaiting
      if !@single_order.has_unscanned_items
        do_for_awaiting_unless_single_order_has_unscanned_items
      else
        @single_order_result['next_state'] = 'scanpack.rfp.default'
        @single_order.last_suggested_at = DateTime.now
        @single_order.scan_start_time ||= DateTime.now
      end
    end

    def do_for_awaiting_unless_single_order_has_unscanned_items
      scanpack_settings_post_scanning_option = @scanpack_settings.post_scanning_option
      current_user_name = @current_user.username

      unless scanpack_settings_post_scanning_option == "None"
        do_if_scanpack_settings_post_scanning_option_not_none(scanpack_settings_post_scanning_option, current_user_name)
      else
        @single_order.set_order_to_scanned_state(current_user_name)
        @single_order_result['next_state'] = 'scanpack.rfo'
      end
    end

    def do_if_scanpack_settings_post_scanning_option_not_none(scanpack_settings_post_scanning_option, current_user_name)
      case true
      when scanpack_settings_post_scanning_option == 'Verify'
        unless @single_order.tracking_num.present?
          @single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
          @single_order.addactivity(
            "Tracking information was not imported with this order so the shipping label could not be verified ",
            @current_user.username
            )
        else
          @single_order_result['next_state'] = 'scanpack.rfp.verifying'
        end
      when scanpack_settings_post_scanning_option == "Record"
        @single_order_result['next_state'] = 'scanpack.rfp.recording'
      when scanpack_settings_post_scanning_option == "PackingSlip"
        #generate packingslip for the order
        @single_order.set_order_to_scanned_state(current_user_name)
        @single_order_result['next_state'] = 'scanpack.rfo'
        generate_packing_slip(@single_order)
      else
        #generate barcode for the order
        @single_order.set_order_to_scanned_state(current_user_name)
        @single_order_result['next_state'] = 'scanpack.rfo'
        generate_order_barcode_slip(@single_order)
      end
    end

  end
end