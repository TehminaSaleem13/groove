# frozen_string_literal: true

module ScanPack
  class ProductScanService < ScanPack::Base
    include ScanPack::Utilities::ProductScan::LotNumber
    include ScanPack::Utilities::ProductScan::ProcessScan
    include ScanPack::Utilities::ProductScan::Barcode
    include ScanPack::Utilities::ProductScan::IndividualProductType
    include ScanPack::Utilities::ProductScan::SingleProductType

    def initialize(args)
      @current_user, @session, @input, @state, @id, @box_id, @on_ex, @typein_count, @type_scan = args
      @result = {
        'status' => true, 'matched' => true, 'error_messages' => [],
        'success_messages' => [], 'notice_messages' => [],
        'data' => {
          'next_state' => 'scanpack.rfp.default', 'serial' => { 'ask' => false }
        }
      }
      @session.merge!(
        product_edit_matched_for_current_user: false,
        order_edit_matched_for_current_user: false,
        product_edit_matched_for_order: false,
        product_edit_matched_for_products: []
      )
      @single_order = Order.where(id: @id).last
      @scanpack_settings = ScanPackSetting.first
    end

    def run(clicked, serial_added, multibarcode = false)
      @multibarcode = multibarcode
      case true
      when @id.blank? || @input.blank?
        set_error_messages('Please scan or enter a valid barcode')
      when @single_order.blank?
        set_error_messages("Could not find order with id:#{@id}")
      else
        product_scan(clicked, serial_added)
      end
      begin
        order = Order.find_by_increment_id(@result['data']['order']['increment_id'])
        @result['data']['order']['store_type'] = order.store.store_type
        @result['data']['order']['popup_shipping_label'] = order.store.shipping_easy_credential.popup_shipping_label if @result['data']['order']['store_type'] == 'ShippingEasy'
        @result['data']['order']['large_popup'] = order.store.shipping_easy_credential.large_popup if @result['data']['order']['store_type'] == 'ShippingEasy'
        @result['data']['order']['order_cup_direct_shipping'] = order.order_cup_direct_shipping
        @result['data']['order']['multiple_lines_per_sku_accepted'] = order.store.shipping_easy_credential.multiple_lines_per_sku_accepted if @result['data']['order']['store_type'] == 'ShippingEasy'
        @result['data']['order']['use_api_create_label'] = order.store.shipstation_rest_credential.use_api_create_label if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        # @result["data"]["order"]["ss_label_data"] = order.store.shipstation_rest_credential.fetch_label_related_data(order.ss_label_data, order.increment_id, order.store_order_id) if !order.has_unscanned_items && @result["data"]["order"]["use_api_create_label"]        @result["data"]["order"]["use_chrome_extention"] = order.store.shipstation_rest_credential.use_chrome_extention if @result["data"]["order"]["store_type"] == "Shipstation API 2" && order.store.shipstation_rest_credential.present?
        @result['data']['order']['use_chrome_extention'] = order.store.shipstation_rest_credential.use_chrome_extention if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['switch_back_button'] = order.store.shipstation_rest_credential.switch_back_button if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['auto_click_create_label'] = order.store.shipstation_rest_credential.auto_click_create_label if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order']['return_to_order'] = order.store.shipstation_rest_credential.return_to_order if @result['data']['order']['store_type'] == 'Shipstation API 2' && order.store.shipstation_rest_credential.present?
        @result['data']['order'] = order.get_se_old_shipments(@result['data']['order'])

        # @result['data']['order']['se_old_split_shipments'] = se_old_split_shipments(order)
        # @result['data']['order']['se_old_combined_shipments'] = se_old_combined_shipments(order) if @result['data']['order']['se_old_split_shipments'].blank?
        # @result['data']['order']['se_all_shipments'] = se_all_shipments(order) if @result['data']['order']['se_old_split_shipments'].blank? && @result['data']['order']['se_old_combined_shipments'].blank?

        if @result['data']['order']['store_type'] == 'Shipstation API 2'
          if Tenant.find_by_name(Apartment::Tenant.current).try(:ss_api_create_label)
            @result['data']['order']['use_api_create_label'] = order.store.shipstation_rest_credential.use_api_create_label if order.store.shipstation_rest_credential.present?
          else
            @result['data']['order']['use_chrome_extention'] = order.store.shipstation_rest_credential.use_chrome_extention if order.store.shipstation_rest_credential.present?
            @result['data']['order']['switch_back_button'] = order.store.shipstation_rest_credential.switch_back_button if order.store.shipstation_rest_credential.present?
            @result['data']['order']['auto_click_create_label'] = order.store.shipstation_rest_credential.auto_click_create_label if order.store.shipstation_rest_credential.present?
            @result['data']['order']['return_to_order'] = order.store.shipstation_rest_credential.return_to_order if order.store.shipstation_rest_credential.present?
          end
        elsif @result['data']['order']['store_type'] == 'ShippingEasy'
          @result['data']['order']['popup_shipping_label'] = order.store.shipping_easy_credential.popup_shipping_label
          @result['data']['order'] = order.get_se_old_shipments(@result['data']['order'])
        end
        do_set_result_for_boxes(order)
      rescue StandardError
      end
      @result
    end

    def product_scan(clicked, serial_added)
      if clicked
        @single_order.clicked_scanned_qty = @single_order.clicked_scanned_qty.to_i + 1
        @single_order.save
      end

      if @scanpack_settings.restart_code_enabled? && @input == @scanpack_settings.restart_code
        do_if_restart_code_is_enabled_and_and_eql_to_input
      elsif @scanpack_settings.service_issue_code_enabled? && @input == @scanpack_settings.service_issue_code
        do_if_service_issue_code_is_enabled_and_and_eql_to_input
      elsif @scanpack_settings.partial? && @input == @scanpack_settings.partial_barcode
        do_if_remove_or_partial_code_is_enabled_and_and_eql_to_input('PARTIAL')
      elsif @scanpack_settings.remove_enabled? && @input == @scanpack_settings.remove_barcode
        do_if_remove_or_partial_code_is_enabled_and_and_eql_to_input('REMOVE')
      elsif @scanpack_settings.scanned && @input == @scanpack_settings.scanned_barcode
        do_if_scanned_code_is_anabled_and_and_eql_to_input
      else
        do_if_restart_code_and_service_issue_code_not_enabled(clicked, serial_added)
      end
      do_if_single_order_present if @single_order.present?

      update_session

      @result
    end

    def update_session
      return unless @result['data']['next_state'].eql?('scanpack.rfo')

      @session[:most_recent_scanned_product] = nil
    end

    def do_if_scanned_code_is_anabled_and_and_eql_to_input
      @single_order.order_items.update_all(scanned_status: 'scanned')
      @single_order.addactivity('Order is scanned through SCANNED barcode', @current_user.try(:username), @on_ex)
      do_if_barcode_found
    end

    def do_if_remove_or_partial_code_is_enabled_and_and_eql_to_input(code_type)

      if code_type == 'PARTIAL'
        @single_order.get_unscanned_items(limit: nil).each do |item|
          qty = remove_skippable_product(item)
          @single_order.addactivity("QTY #{qty} of SKU #{item['sku']} was removed using the PARTIAL barcode", @current_user.try(:username), @on_ex)
        end
      elsif code_type == 'REMOVE'
        item = @single_order.get_unscanned_items(limit: nil).first
        qty = item['product_type'] == 'individual' ? remove_kit_product_item_from_order(item['child_items'].first) : remove_skippable_product(item)
        @single_order.addactivity("QTY #{qty} of SKU #{item['product_type'] == 'individual' ? item['child_items'].first['sku'] : item['sku']} was removed using the REMOVE barcode", @current_user.try(:username), @on_ex)
      end
      do_if_barcode_found
    end

    def do_if_restart_code_and_service_issue_code_not_enabled(clicked, serial_added)
      escape_string = ''
      @input = @input.gsub((@scanpack_settings.string_removal || ''), '') if @scanpack_settings.string_removal_enabled && !@input.index(@scanpack_settings.string_removal || '').nil?
      if @scanpack_settings.escape_string_enabled && !clicked
        first_escape_string = @scanpack_settings.escape_string
        second_escape_string = @scanpack_settings.second_escape_string
        first_escape = @scanpack_settings.first_escape_string_enabled && first_escape_string.present? && !@input.index(first_escape_string || '').nil?
        second_escape = @scanpack_settings.second_escape_string_enabled && second_escape_string.present? && !@input.index(second_escape_string || '').nil?
        clean_input = if first_escape && second_escape
                        @input.split(first_escape_string)[0].split(second_escape_string)[0]
                      elsif first_escape
                        @input.slice(0..(@input.index(first_escape_string || '') - 1))
                      elsif second_escape
                        @input.slice(0..(@input.index(second_escape_string || '') - 1))
                      else
                        @input
                      end
      else
        clean_input = @input
      end
      # if @scanpack_settings.escape_string_enabled && !@input.index(@scanpack_settings.escape_string).nil?
      #   clean_input = @input.slice(0..(@input.index(@scanpack_settings.escape_string)-1))
      # else
      #   clean_input = @input
      # end

      @result['data'].merge!(
        'serial' => {
          'clicked' => clicked,
          'barcode' => clean_input,
          'order_id' => @id
        },
        'order_num' => @single_order.increment_id
      )

      if @single_order.has_unscanned_items
        case @scanpack_settings.scanning_sequence
        when 'any_sequence'
          do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
        when 'items_sequence'
          unscanned_items = @single_order.get_unscanned_items(barcode: clean_input)
          if check_scanning_item(unscanned_items, clean_input)
            do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
          else
            @single_order.inaccurate_scan_count = @single_order.inaccurate_scan_count + 1
            @single_order.addactivity("OUT OF SEQUENCE - Product with barcode: #{unscanned_items.first['barcodes'].map(&:barcode).first} was suggested and barcode: #{clean_input} was scanned", @current_user&.username || 'gpadmin')
            @result['status'] &= false
            message = check_for_skip_settings(clean_input) ? "The currently suggested item does not have the \'Skippable\' option enabled" : 'Please scan items in the suggested order'
            @result['error_messages'].push(message)
          end
        when 'kits_sequence'
          do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
          # list = check_scanning_kit(clean_input)
          # if list.empty?
          #   do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
          # elsif list.include?(clean_input)
          #   do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
          # else
          #   @single_order.addactivity("OUT OF SEQUENCE - Product with barcode: #{list.first} was suggested and barcode: #{clean_input} was scanned", @current_user&.username || 'gpadmin')
          #   @result['status'] &= false
          #   @result['error_messages'].push("Please scan items in the suggested order")
          # end
        when 'kit_packing_mode'
          list = check_kit_mode(clean_input)
          if list.empty? || list.include?(clean_input) || check_for_skip_settings(clean_input)
            do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
          else
            @single_order.inaccurate_scan_count = @single_order.inaccurate_scan_count + 1
            @single_order.addactivity("OUT OF SEQUENCE - Product with barcode: #{list.first} was suggested and barcode: #{clean_input} was scanned", @current_user&.username || 'gpadmin')
            @result['status'] &= false
            @result['error_messages'].push('Please scan items in the suggested order')
          end
        end
      else
        @result['status'] &= false
        @result['error_messages'].push('There are no unscanned items in this order')
      end
    end

    def check_scanning_item(unscanned_items, clean_input)
      list = []
      list << unscanned_items.first['barcodes'].map(&:barcode)
      unless unscanned_items.first['child_items'].nil?
        # data = []
        # unscanned_items.first["child_items"].each do |child_item|
        #   data << child_item["barcodes"].map(&:barcode)
        # end
        # list << data
        list << unscanned_items.first['child_items'].first['barcodes'].map(&:barcode)
      end
      value = list.flatten.include?(clean_input.to_s)
      value = check_for_skippable_item(unscanned_items.first) if !value && check_for_skip_settings(clean_input)
      value
    end

    def check_for_skip_settings(clean_input)
      @scanpack_settings.skip_code_enabled && @scanpack_settings.skip_code == clean_input
    end

    def check_for_skippable_item(item)
      val = item['skippable']
      val = item['child_items'].first['skippable'] if !val && item['child_items'].present?
      val
    end

    # def check_scanning_kit(clean_input)
    #   unscanned_items = @single_order.get_unscanned_items(barcode: clean_input)
    #   data = []
    #   list = []
    #   unscanned_items.each do |item|
    #     data << item if item["partially_scanned"] == true
    #   end
    #   if data.any?
    #     if data.first["child_items"].present?
    #       data.first["child_items"].each do |i|
    #         list << i["barcodes"].map(&:barcode)
    #       end
    #     end
    #   end
    #   return list.flatten
    # end

    def check_kit_mode(clean_input)
      total_items = @single_order.get_unscanned_items(barcode: clean_input)
      list = []
      total_items.each do |item|
        next unless item['partially_scanned'] == true && item['child_items'].present?

        item['child_items'].each do |i|
          list << i['barcodes'].map(&:barcode) if (item['qty_remaining'] * i['product_qty_in_kit'] - i['product_qty_in_kit']) < i['qty_remaining']
        end
      end
      list.flatten
    end

    def do_if_service_issue_code_is_enabled_and_and_eql_to_input
      if @single_order.status != 'scanned'
        @single_order.reset_scanned_status(@current_user, @on_ex)
        @single_order.status = 'serviceissue'
        @result['data']['next_state'] = 'scanpack.rfo'
        @result['data']['ask_note'] = true
      else
        set_error_messages('Order with id: ' + @id + ' is already in scanned state')
      end
    end

    def do_if_restart_code_is_enabled_and_and_eql_to_input
      if @single_order.status != 'scanned'
        @single_order.reset_scanned_status(@current_user, @on_ex)
        @result['data']['next_state'] = 'scanpack.rfo'
      else
        set_error_messages('Order with id: ' + @id.to_s + ' is already in scanned state')
      end
    end

    def do_if_single_order_present
      @single_order.packing_user_id = @current_user.id
      set_error_messages("Could not save order with id: #{@single_order.id}") unless @single_order.save
      @result['data']['order'] = order_details_and_next_item
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end

    def do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
      @split_kit_order = @single_order.should_the_kit_be_split(clean_input) if @single_order.contains_kit && @single_order.contains_splittable_kit

      @single_order.last_suggested_at ||= DateTime.now.in_time_zone
      @single_order.save

      unscanned_items = @single_order.get_unscanned_items(barcode: clean_input)
      # search if barcode exists
      if check_for_skip_settings(clean_input)
        barcode_found = check_for_skippable_item(unscanned_items.first)
        barcode_found = do_set_barcode_found_flag(unscanned_items, clean_input, serial_added, clicked) if barcode_found
      else
        barcode_found = do_set_barcode_found_flag(unscanned_items, clean_input, serial_added, clicked)
        barcode_found ||= do_if_barcode_not_found(clean_input, serial_added, clicked)
      end

      if barcode_found
        last_activity = @single_order.order_activities.last
        action_keyword = last_activity.try(:action).try(:split, ' ')
        sku_for_activity = begin
                             @order_item.product.primary_sku
                           rescue StandardError
                             nil
                           end
        order_item_sku = begin
                           sku_for_activity.split(' ')[0]
                         rescue StandardError
                           nil
                         end
        type_in_count = @typein_count
        if action_keyword.present? && order_item_sku.present? && action_keyword.include?(order_item_sku) && @typein_count > 1
          if action_keyword.include?('click')
            type_in_count = @typein_count.to_i + 1
            last_activity.action += ' for a Type-In count'
            last_activity.save
          elsif action_keyword.include?('barcode:')
            type_in_count = @typein_count.to_i + 1
          end
        end
        add_log(sku_for_activity, type_in_count)
        do_if_barcode_found
      else
        if Apartment::Tenant.current == 'gp50'
          log = { tenant: Apartment::Tenant.current, clean_input: clean_input, unscanned_items: unscanned_items, split_kit_order: @split_kit_order }
          File.open("#{Rails.root}/kit_scan_3_issue_#{Apartment::Tenant.current}.yaml", 'a') { |f| f.write(log.to_yaml) }
        end
        @single_order.inaccurate_scan_count = @single_order.inaccurate_scan_count + 1
        @result['status'] &= false

        msg = @scanpack_settings.scanning_sequence == 'items_sequence' ? "Barcode '#{clean_input}'' does not match the currently suggested item" : "Barcode '" + clean_input + "' doesn't match any item remaining on this order"

        message = check_for_skip_settings(clean_input) ? "The currently suggested item does not have the \'Skippable\' option enabled" : msg
        @result['error_messages'].push(message)
      end
    end

    def do_set_barcode_found_flag(unscanned_items, clean_input, serial_added, clicked)
      barcode_found = false
      unscanned_items.each do |item|
        if item['product_type'] == 'individual'
          barcode_found = do_if_product_type_is_individual([item, clean_input, serial_added, clicked, barcode_found, @type_scan])
        elsif item['product_type'] == 'single'
          barcode_found = do_if_product_type_is_single([item, clean_input, serial_added, clicked, barcode_found, @type_scan])
        end
        break if barcode_found
      end
      barcode_found
    end

    def do_set_result_for_boxes(order)
      result = order.get_boxes_data
      @result['data']['order']['box'] = result[:box]
      @result['data']['order']['order_item_boxes'] = result[:order_item_boxes]
    end

    def add_log(sku_for_activity, type_in_count)
      general_setting = GeneralSetting.last
      if @multibarcode
        if @box_id.nil?
          if general_setting.multi_box_shipments?
            @single_order.addactivity("Multibarcode count of #{@typein_count} scanned for product #{sku_for_activity} in Box 1", @current_user.username)
          else
            @single_order.addactivity("Multibarcode count of #{@typein_count} scanned for product #{sku_for_activity}", @current_user.username)
          end
        else
          box = Box.find_by_id(@box_id)
          @single_order.addactivity("Multibarcode count of #{@typein_count} scanned for product #{sku_for_activity} in #{box.try(:name)}", @current_user.username)
        end
      else
        if @box_id.nil?
          if general_setting.multi_box_shipments?
            @single_order.addactivity("Type-In count of #{type_in_count} entered for product #{sku_for_activity} in Box 1", @current_user.username) if @typein_count > 1 && !@scanpack_settings.order_verification
          else
            @single_order.addactivity("Type-In count of #{type_in_count} entered for product #{sku_for_activity}", @current_user.username) if @typein_count > 1 && !@scanpack_settings.order_verification
          end
        else
          box = Box.find_by_id(@box_id)
          @single_order.addactivity("Type-In count of #{type_in_count} entered for product #{sku_for_activity} in #{box.try(:name)}", @current_user.username) if @typein_count > 1 && !@scanpack_settings.order_verification
        end
      end
    end
  end # class end
end # module end
