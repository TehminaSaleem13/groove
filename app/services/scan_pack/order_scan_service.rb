# frozen_string_literal: true

module ScanPack
  class OrderScanService < ScanPack::Base
    def initialize(current_user, session, input, state, id, store_order_id, order_by_number)
      @current_user = current_user
      @input = input
      @state = state
      @id = id
      @store_order_id = store_order_id
      @result = {
        'status' => true,
        'matched' => true,
        'do_on_demand_import' => false,
        'error_messages' => [],
        'success_messages' => [],
        'notice_messages' => [],
        'data' => {
          'next_state' => 'scanpack.rfo'
        }
      }
      @orders = []
      @scanpack_settings = ScanPackSetting.all.first
      @session = session.merge!(most_recent_scanned_product: nil,
                                parent_order_item: false)
      @single_order = nil
      @single_order_result = { 'matched_orders' => [] }
      @scan_by_id = check_for_hex
      @se_shipment_handling_v2_present = (Store.where(store_type: 'ShippingEasy').pluck(:split_order) & %w[shipment_handling_v2 verify_separately]).any?
      @order_by_number = order_by_number
      @scan_by_tracking_num = @scanpack_settings.scan_by_shipping_label && !@order_by_number
    end

    def run
      order_scan if valid_input?
      @result
    end

    def valid_input?
      if @scan_by_tracking_num
        validity = @input.strip.length >= 10
        msg = 'Please provide a valid tracking number with 8 or more characters.'
      else
        validity = @input.present?
        msg = 'Please specify a barcode to scan the order'
      end
      unless validity
        @result['status'] &= false
        @result['error_messages'].push(msg)
      end
      validity
    end

    def order_scan
      collect_orders
      @single_order, @single_order_result = get_single_order_with_result

      if @single_order_result['matched_orders'].count > 0
        @single_order = @orders.where(store_order_id: @store_order_id).first if @store_order_id.to_i != 0
        @single_order_result['matched_orders'] = @single_order_result['matched_orders'].collect do |matched_order|
          matched_order.attributes.merge(items_count: matched_order.get_items_count)
        end
      end

      do_if_single_order_not_present && return unless @single_order
      do_if_single_order_present
    end

    def collect_orders
      if (@scanpack_settings.scan_by_shipping_label || @scanpack_settings.scan_by_packing_slip_or_shipping_label) && !@order_by_number
        @orders = Order.includes(%i[store order_items]).where(tracking_num: @input).where('LENGTH(tracking_num) >= 8').order('LENGTH(tracking_num) DESC')
        @orders = Order.includes(%i[store order_items]).where('? LIKE CONCAT("%", tracking_num, "%") and LENGTH(tracking_num) >= 8', @input).order('LENGTH(tracking_num) DESC') if @orders.blank?
        if @orders.first.try(:status) == 'scanned' && @scanpack_settings.scan_by_packing_slip_or_shipping_label
          old_orders = @orders
          @orders = []
          find_order
          @orders = old_orders unless @orders.any?
        end
        find_order if @orders.blank? && @scanpack_settings.scan_by_packing_slip_or_shipping_label
      else
        find_order
      end
      @single_order = @orders.first
    end

    def find_order
      ["('awaiting')", "('onhold')", "('serviceissue', 'cancelled', 'scanned')"].each do |status|
        return unless @orders.blank?

        query = generate_query(status)
        @orders = Order.includes(%i[store order_items]).where(query)
      end
    end

    def generate_query(status)
      input_without_special_char = ActiveRecord::Base.connection.quote(@input.downcase.gsub(/^(\#)|(\-*)/, '').try { |a| a.gsub(/(\W)/, &:to_s) })
      input_with_special_char = ActiveRecord::Base.connection.quote(@input.downcase.try { |a| a.gsub(/(\W)/, &:to_s) })
      se_order_input = ActiveRecord::Base.connection.quote(input_without_special_char + ' (')
      input_with_special_char_without_space = ActiveRecord::Base.connection.quote(input_with_special_char.gsub(/\s+/, ''))
      input_without_special_char_without_space = input_without_special_char.gsub(/\s+/, '')

      # id = @scanpack_settings.scan_by_hex_number ? 'store_order_id' : 'increment_id'
      # %(\
      #   (#{id} IN \(\
      #     '#{input_with_special_char}', '\##{input_with_special_char}'\
      #   \) or \
      #   non_hyphen_increment_id IN \(\
      #     '#{input_without_special_char}', '\##{input_without_special_char}'\
      #   \)) and status IN #{status} and updated_at >= #{(Time.current-14.days).strftime("%Y-%m-%d")}
      # )
      # if @se_shipment_handling_v2_present
      #   # %(\
      #   #   (#{@scan_by_id} LIKE '#{input_with_special_char}%' and \(\
      #   #     orders.status IN #{status} and orders.updated_at >= #{(Time.current - 14.days).strftime('%Y-%m-%d')}
      #   #   \))
      #   # )
      #   %(\
      #     (#{@scan_by_id} IN \(\
      #       #{input_with_special_char}, "\##{input_with_special_char}"\
      #     \) or \
      #     #{@scan_by_id} LIKE \(\
      #       #{se_order_input}
      #     \) or \
      #     non_hyphen_increment_id IN \(\
      #       #{input_without_special_char}, "\##{input_without_special_char}"\
      #     \) or \
      #       #{@scan_by_id} IN \(\
      #       #{input_with_special_char_without_space}, "\##{input_with_special_char_without_space}"\
      #     \) or \
      #     non_hyphen_increment_id IN \(\
      #       #{input_without_special_char_without_space}, "\##{input_without_special_char_without_space}"\
      #     \)) and orders.status IN #{status} and orders.updated_at >= #{(Time.current - 14.days).strftime('%Y-%m-%d')}
      #   )
      # else
      #   %(\
      #     (#{@scan_by_id} IN \(\
      #       #{input_with_special_char}, "\##{input_with_special_char}"\
      #     \) or \
      #     non_hyphen_increment_id IN \(\
      #       #{input_without_special_char}, "\##{input_without_special_char}"\
      #     \) or \
      #       #{@scan_by_id} IN \(\
      #       #{input_with_special_char_without_space}, "\##{input_with_special_char_without_space}"\
      #     \) or \
      #     non_hyphen_increment_id IN \(\
      #       #{input_without_special_char_without_space}, "\##{input_without_special_char_without_space}"\
      #     \)) and orders.status IN #{status} and orders.updated_at >= #{(Time.current - 14.days).strftime('%Y-%m-%d')}
      #   )
      # end

      base_query = [
        "lower(#{@scan_by_id}) IN (#{input_with_special_char}, \"##{input_with_special_char}\")",
        "lower(non_hyphen_increment_id) IN (#{input_without_special_char}, \"##{input_without_special_char}\")",
        "lower(#{@scan_by_id}) IN (#{input_with_special_char_without_space}, \"##{input_with_special_char_without_space}\")",
        "lower(non_hyphen_increment_id) IN (#{input_without_special_char_without_space}, \"##{input_without_special_char_without_space}\")"
      ]

      final_query = if @se_shipment_handling_v2_present
        base_query + ["lower(#{@scan_by_id}) LIKE #{se_order_input}"]
      else
        base_query
      end

      "(#{final_query.join(' OR ')}) AND orders.status IN #{status} "
    end

    def get_single_order_with_result
      # assign @single_order = first order for only one order
      return [@orders.first, @single_order_result] if @orders.size == 1

      @orders.each do |matched_single|
        matched_single_status, matched_single_order_placed_time,
        single_order_status, single_order_order_placed_time,
        order_placed_for_single_before_than_matched_single = do_set_check_variables(matched_single)
        do_check_order_status_for_single_and_matched(
          matched_single, single_order_status, matched_single_status,
          order_placed_for_single_before_than_matched_single
        ) if @single_order

        unless %w(scanned cancelled).include?(matched_single_status)
          @single_order_result['matched_orders'].push(matched_single)
        end
      end

      [@single_order, @single_order_result]
    end

    def do_set_check_variables(matched_single)
      do_check_increment_id(matched_single)
      matched_single_status = matched_single.status
      matched_single_order_placed_time = matched_single.order_placed_time || Time.zone.now
      single_order_status = @single_order.status
      single_order_order_placed_time = @single_order.order_placed_time || Time.zone.now
      order_placed_for_single_before_than_matched_single = single_order_order_placed_time < matched_single_order_placed_time

      [
        matched_single_status, matched_single_order_placed_time, single_order_status,
        single_order_order_placed_time, order_placed_for_single_before_than_matched_single
      ]
    end

    def do_check_increment_id(matched_single)
      @single_order = matched_single if matched_single.increment_id.casecmp(@input.squish.downcase).zero?
    end

    def do_check_order_status_for_single_and_matched(
      matched_single, single_order_status, matched_single_status,
      order_placed_for_single_before_than_matched_single
    )
      %w[awaiting onhold serviceissue].each do |status|
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
      message = if @scanpack_settings.scan_by_shipping_label
                  'Order with tracking number ' + @input +
                    ' cannot be found. It may not have been imported yet'
                else
                  'Order with number ' + @input +
                    ' cannot be found. It may not have been imported yet'
      end
      @result['matched'] = false
      @result['do_on_demand_import'] = true
      @result['error_messages'].push(message)
    end

    def do_if_single_order_present
      @single_order_result['status'] = @single_order.status
      @single_order_result['order_num'] = @single_order.increment_id
      @single_order_result['store_order_id'] = @single_order.store_order_id

      # Check if order has inactive/new/0qty items but still in awaiting
      check_if_order_update_needed_and_clear_cache

      if can_order_be_scanned
        do_if_under_max_limit_of_shipments
        # else
        #   @result['status'] &= false
        #   @result['error_messages'].push(
        #     "You have reached the maximum limit of number of shipments for your subscription."
        #     )
        #   @single_order_result['next_state'] = 'scanpack.rfo'
      end
      @result['data'] = @single_order_result
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end

    def check_if_order_update_needed_and_clear_cache
      single_order_status = @single_order.status
      has_inactive_or_new_products = @single_order.has_inactive_or_new_products

      # Rails.cache.clear

      return unless @single_order.order_items.present? &&
                    (
                      (single_order_status.eql?('awaiting') && has_inactive_or_new_products) ||
                      (single_order_status.eql?('onhold') && !has_inactive_or_new_products)
                    )

      @single_order.update_order_status
    end

    def do_if_under_max_limit_of_shipments
      single_order_status = @single_order.status
      has_inactive_or_new_products = @single_order.has_inactive_or_new_products

      unless single_order_status == 'scanned'
        @single_order.packing_user_id = @current_user.id
        @single_order.save
      end
      # PROCESS based on Order Status
      #-----------------------------
      # search in orders that have status of Scanned
      if single_order_status.eql?('scanned')
        do_if_already_been_scanned
      # elsif @single_order.already_scanned && @scanpack_settings.order_verification
      #   @single_order_result['scanned_on'] = @single_order.scanned_on
      #   do_if_single_order_status_awaiting if single_order_status.eql?('awaiting')
      #   @single_order_result['next_state'] = 'scanpack.rfo'
      #   @single_order.status = "scanned"
      #   @single_order.save
      elsif @scanpack_settings.order_verification && single_order_status.eql?('awaiting')
        @single_order.order_items.each do |order_item|
          product = order_item.product
          if product.is_kit == 1
            product.product_kit_skuss.each do |kit_item|
              kit_item.qty.times do
                barcode = begin
                            Product.find_by_id(kit_item.option_product_id).product_barcodes[0].barcode
                          rescue StandardError
                            nil
                          end
                single_scan(barcode, order_item)
              end
            end
          else
            barcode = begin
                        order_item.product.product_barcodes.map(&:barcode)[0]
                      rescue StandardError
                        nil
                      end
            single_scan(barcode, order_item)
          end
        end
        @single_order.addactivity("Order with order number: #{@single_order.increment_id} was scanned using Single Scan Verification", @current_user.username)
        @result['success_messages'].push('This order marked as scanned')
        @single_order_result['next_state'] = 'scanpack.rfp.default'
      else
        check_removal_zero_qty_item
        do_if_single_order_status_on_hold(has_inactive_or_new_products) if single_order_status.eql?('onhold')
        # process orders that have status of Service Issue
        do_if_single_order_status_serviceissue if single_order_status.eql?('serviceissue')
        # search in orders that have status of Cancelled
        do_if_single_order_status_cancelled if single_order_status.eql?('cancelled')
        # if order has status of Awaiting Scanning
        do_if_single_order_status_awaiting if single_order_status.eql?('awaiting')
        #----------------------------
      end
      do_if_single_order_present_and_under_max_limit_of_shipment if @single_order
    end

    def single_scan(barcode, order_item)
      product_scan_object = ScanPack::ProductScanService.new(
        [@current_user, {}, barcode, 'scanpack.rfp.default', @single_order.id, nil, order_item.qty || 1]
      )
      product_scan_object.run(true, '')
    end

    def do_if_single_order_present_and_under_max_limit_of_shipment
      unless @single_order.save
        @result['status'] &= false
        @result['error_messages'].push('Could not save order with id: ' + @single_order.id.to_s)
      end
      @single_order_result['order'] = order_details_and_next_item
    end

    def do_if_already_been_scanned
      @single_order_result['scanned_on'] = @single_order.scanned_on
      @single_order_result['next_state'] = 'scanpack.rfo'
      @result['notice_messages'].push('This order has already been scanned')
    end

    def check_removal_zero_qty_item
      if GeneralSetting.last.remove_order_items
        data = []
        @single_order.reload.order_items.each do |order_item|
          data << order_item if order_item.qty.eql?(0) && order_item.skipped_qty.eql?(0)
        end
        if data.any?
          data.each do |item|
            product = item.product
            sku = begin
                    product.product_skus.first.sku
                  rescue StandardError
                    nil
                  end
            item.order.addactivity('Item with sku ' + sku.to_s + ' having 0 qty removed', 'GroovePacker Automaticaly')
            item.delete
          end
          @single_order.reload.order_items
          @single_order.update_order_status
          message = 'An item with quantity of 0 has been removed from this order'
          @result['notice_messages'].push(message)
        end
      end
    end

    def do_if_single_order_status_on_hold(has_inactive_or_new_products)
      if has_inactive_or_new_products
        # get list of inactive_or_new_products
        @single_order_result['conf_code'] = @session[:confirmation_code]

        if @current_user.can?('add_edit_products') || (
            @session[:product_edit_matched_for_current_user] &&
            @session[:product_edit_matched_for_order] == @single_order.id
          )
          @single_order_result.merge!('product_edit_matched' => true,
                                      'inactive_or_new_products' => @single_order.get_inactive_or_new_products,
                                      'next_state' => 'scanpack.rfp.product_edit')

          message = check_for_zero_qty_item

        else
          @session.merge!(product_edit_matched_for_current_user: false,
                          order_edit_matched_for_current_user: false,
                          product_edit_matched_for_order: false,
                          product_edit_matched_for_products: [])
          @single_order_result['next_state'] = 'scanpack.rfp.confirmation.product_edit'
          message = "The order you've scanned has a status of Action Required because it contains items that are New or Inactive. Often one or more items in the order need to have a barcode added. This will require Product Edit permissions. <br />" \
          'Please ask a user with product edit permissions to scan or enter their confirmation code if you wish to add the barcodes and continue packing this order. Alternatively you can scan a different packing slip to pack another order.'
        end
      else
        @single_order_result['order_edit_permission'] = @current_user.can?('import_orders')
        @single_order_result['next_state'] = 'scanpack.rfp.confirmation.order_edit'
        message = 'This order is currently on Hold. Please scan or enter '\
         'confirmation code with order edit permission to continue scanning '\
         'this order or scan a different order.'
      end
      message && @result['notice_messages'].push(message)
    end

    def check_for_zero_qty_item
      contains_zero_qty_order_item = @single_order.contains_zero_qty_order_item?
      contains_zero_qty_order_kit_item = @single_order.contains_zero_qty_order_kit_item?

      return unless contains_zero_qty_order_item || contains_zero_qty_order_kit_item

      @single_order_result['zero_qty_product'] = contains_zero_qty_order_item

      message = if contains_zero_qty_order_kit_item
                  'The current order has one or more kit items with a qty of 0'
                else
                  'The current order has one or more items with a qty of 0'
      end

      message
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
        @single_order.last_suggested_at = DateTime.now.in_time_zone
        @single_order.scan_start_time ||= DateTime.now.in_time_zone
      end
    end

    def do_for_awaiting_unless_single_order_has_unscanned_items
      scanpack_settings_post_scanning_option = @scanpack_settings.post_scanning_option
      current_user_name = @current_user.username

      if scanpack_settings_post_scanning_option == 'None' || @scanpack_settings.order_verification
        @single_order.set_order_to_scanned_state(current_user_name)
        @single_order_result['next_state'] = 'scanpack.rfo'
      else
        do_if_scanpack_settings_post_scanning_option_not_none(scanpack_settings_post_scanning_option, current_user_name)
      end
    end

    def do_if_scanpack_settings_post_scanning_option_not_none(scanpack_settings_post_scanning_option, _current_user_name)
      if @single_order.post_scanning_flag.nil?
        case true
        when scanpack_settings_post_scanning_option == 'Verify'
          if @single_order.tracking_num.present?
            @single_order_result['next_state'] = 'scanpack.rfp.verifying'
          else
            @single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
            @single_order.addactivity(
              'Tracking information was not imported with this order so the shipping label could not be verified ',
              @current_user.username
            )
          end
        when scanpack_settings_post_scanning_option == 'Record'
          @single_order_result['next_state'] = 'scanpack.rfp.recording'
        when scanpack_settings_post_scanning_option == 'PackingSlip'
          # generate packingslip for the order
          # @single_order.set_order_to_scanned_state(current_user_name)
          # @single_order_result['next_state'] = 'scanpack.rfo'
          apply_second_action
          generate_packing_slip(@single_order)
          @single_order.update_columns(post_scanning_flag: 'PackingSlip')
        else
          # generate barcode for the order
          # @single_order.set_order_to_scanned_state(current_user_name)
          # @single_order_result['next_state'] = 'scanpack.rfo'
          apply_second_action
          @single_order.update_columns(post_scanning_flag: 'Barcode')
          generate_order_barcode_slip(@single_order)
        end
      else
        apply_second_action
      end
    end

    def apply_second_action
      case @scanpack_settings.post_scanning_option_second
      when 'Verify'
        if @single_order.tracking_num.present?
          @single_order_result['next_state'] = 'scanpack.rfp.verifying'
        else
          @single_order_result['next_state'] = 'scanpack.rfp.no_tracking_info'
          @single_order.addactivity(
            'Tracking information was not imported with this order so the shipping label could not be verified ',
            @current_user.username
          )
        end
      when 'PackingSlip'
        @single_order_result['next_state'] = 'scanpack.rfo'
        set_order_scanned_state_and_result_data
        generate_packing_slip(@single_order)
      when 'Barcode'
        set_order_scanned_state_and_result_data
        generate_order_barcode_slip(@single_order)
      when 'Record'
        @single_order_result['next_state'] = 'scanpack.rfp.recording'
      else
        set_order_scanned_state_and_result_data
      end
    end

    def set_order_scanned_state_and_result_data
      @single_order.set_order_to_scanned_state(@current_user.username)
      @single_order_result['next_state'] = 'scanpack.rfo'
    end
  end
end
