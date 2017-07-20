module ScanPack
  class ProductScanService < ScanPack::Base
    include ScanPack::Utilities::ProductScan::LotNumber
    include ScanPack::Utilities::ProductScan::ProcessScan
    include ScanPack::Utilities::ProductScan::Barcode
    include ScanPack::Utilities::ProductScan::IndividualProductType
    include ScanPack::Utilities::ProductScan::SingleProductType

    def initialize(args)
      @current_user, @session, @input, @state, @id, @typein_count = args
      @result = {
        "status"=>true, "matched"=>true, "error_messages"=>[],
        "success_messages"=>[], "notice_messages"=>[],
        "data"=>{
          "next_state"=>"scanpack.rfp.default", "serial"=>{"ask"=>false}}
        }
      @session.merge!({
        product_edit_matched_for_current_user: false,
        order_edit_matched_for_current_user: false,
        product_edit_matched_for_order: false,
        product_edit_matched_for_products: []
        })
      @single_order = Order.where(id: @id).last
      @scanpack_settings = ScanPackSetting.first
    end

    def run(clicked, serial_added, multibarcode=false)
      @multibarcode = multibarcode
      case true
      when @id.blank? || @input.blank?
        set_error_messages('Please specify barcode and order id to confirm purchase code')
      when @single_order.blank?
        set_error_messages("Could not find order with id:#{@id}")
      else
        product_scan(clicked, serial_added)
      end
      begin
        order = Order.find_by_increment_id(@result["data"]["order"]["increment_id"]) 
        @result["data"]["order"]["store_type"] = order.store.store_type 
        @result["data"]["order"]["popup_shipping_label"] = order.store.shipping_easy_credential.popup_shipping_label if @result["data"]["order"]["store_type"] == "ShippingEasy"
        @result["data"]["order"]["use_chrome_extention"] = order.store.shipstation_rest_credential.use_chrome_extention if @result["data"]["order"]["store_type"] == "Shipstation API 2"
        @result["data"]["order"]["switch_back_button"] = order.store.shipstation_rest_credential.switch_back_button if @result["data"]["order"]["store_type"] == "Shipstation API 2"
        @result["data"]["order"]["auto_click_create_label"] = order.store.shipstation_rest_credential.auto_click_create_label if @result["data"]["order"]["store_type"] == "Shipstation API 2"
      rescue
      end
      @result
    end

    def product_scan(clicked, serial_added)
      case
      when @scanpack_settings.restart_code_enabled? && @input == @scanpack_settings.restart_code
        do_if_restart_code_is_enabled_and_and_eql_to_input
      when @scanpack_settings.service_issue_code_enabled? && @input == @scanpack_settings.service_issue_code
        do_if_service_issue_code_is_enabled_and_and_eql_to_input
      else
        do_if_restart_code_and_service_issue_code_not_enabled(clicked, serial_added)
      end

      do_if_single_order_present if @single_order.present?

      update_session

      return @result
    end

    def update_session
      return unless @result['data']['next_state'].eql?('scanpack.rfo')
      @session[:most_recent_scanned_product] = nil
    end

    def do_if_restart_code_and_service_issue_code_not_enabled(clicked, serial_added)
      escape_string = ''
      @input = @input.gsub((@scanpack_settings.string_removal || ""), "") if @scanpack_settings.string_removal_enabled && !@input.index(@scanpack_settings.string_removal || "").nil?
      if @scanpack_settings.escape_string_enabled  
        first_escape_string = @scanpack_settings.escape_string
        second_escape_string = @scanpack_settings.second_escape_string
        first_escape = @scanpack_settings.first_escape_string_enabled && first_escape_string.present? && !@input.index(first_escape_string || "").nil?
        second_escape = @scanpack_settings.second_escape_string_enabled && second_escape_string.present? && !@input.index(second_escape_string || "").nil?
        if first_escape && second_escape
          clean_input = @input.split(first_escape_string)[0].split(second_escape_string)[0]
        elsif first_escape
          clean_input = @input.slice(0..(@input.index(first_escape_string || "")-1))
        elsif second_escape
          clean_input = @input.slice(0..(@input.index(second_escape_string || "")-1)) 
        else
          clean_input = @input   
        end
      else
        clean_input = @input 
      end
      # if @scanpack_settings.escape_string_enabled && !@input.index(@scanpack_settings.escape_string).nil?
      #   clean_input = @input.slice(0..(@input.index(@scanpack_settings.escape_string)-1))
      # else
      #   clean_input = @input
      # end

      @result['data'].merge!({
        'serial' => {
          'clicked' => clicked,
          'barcode' => clean_input,
          'order_id' => @id
        },
        'order_num' => @single_order.increment_id
      })

      if @single_order.has_unscanned_items
        do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
      else
        @result['status'] &= false
        @result['error_messages'].push("There are no unscanned items in this order")
      end
    end

    def do_if_service_issue_code_is_enabled_and_and_eql_to_input
      if @single_order.status !='scanned'
        @single_order.reset_scanned_status(@current_user)
        @single_order.status = 'serviceissue'
        @result['data']['next_state'] = 'scanpack.rfo'
        @result['data']['ask_note'] = true
      else
        set_error_messages('Order with id: '+@id+' is already in scanned state')
      end
    end

    def do_if_restart_code_is_enabled_and_and_eql_to_input
      if @single_order.status != 'scanned'
        @single_order.reset_scanned_status(@current_user)
        @result['data']['next_state'] = 'scanpack.rfo'
      else
        set_error_messages('Order with id: '+@id.to_s+' is already in scanned state')
      end
    end

    def do_if_single_order_present
      @single_order.packing_user_id = @current_user.id
      unless @single_order.save
        set_error_messages("Could not save order with id: #{@single_order.id}")
      end
      @result['data']['order'] = order_details_and_next_item
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end

    def do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
      @single_order.should_the_kit_be_split(clean_input) if @single_order.contains_kit && @single_order.contains_splittable_kit

      @single_order.last_suggested_at ||= DateTime.now
      @single_order.save

      unscanned_items = @single_order.get_unscanned_items(barcode: clean_input)
      #search if barcode exists
      barcode_found = do_set_barcode_found_flag(unscanned_items, clean_input, serial_added, clicked)

      barcode_found = do_if_barcode_not_found(clean_input, serial_added, clicked) unless barcode_found

      if barcode_found
        last_activity = @single_order.order_activities.last
        action_keyword = last_activity.try(:action).try(:split, ' ')
        sku_for_activity = @order_item.product.primary_sku rescue nil
        order_item_sku = sku_for_activity.split(' ')[0] rescue nil
        type_in_count = @typein_count
        if action_keyword.present? && order_item_sku.present? && action_keyword.include?(order_item_sku) && @typein_count > 1
          if action_keyword.include?("click")
            type_in_count = @typein_count.to_i + 1
            last_activity.action  += " for a Type-In count"
            last_activity.save
          elsif action_keyword.include?("barcode:")
            type_in_count = @typein_count.to_i + 1
          end
        end
        if @multibarcode
          @single_order.addactivity("Multibarcode count of #{@typein_count} scanned for product #{sku_for_activity}", @current_user.username)
        else
          @single_order.addactivity("Type-In count of #{type_in_count} entered for product #{sku_for_activity}", @current_user.username) if @typein_count > 1
        end
        do_if_barcode_found
      else
        @single_order.inaccurate_scan_count = @single_order.inaccurate_scan_count + 1
        @result['status'] &= false
        @result['error_messages'].push("Barcode '"+clean_input+"' doesn't match any item remaining on this order")
      end
    end

    def do_set_barcode_found_flag(unscanned_items, clean_input, serial_added, clicked)
      barcode_found = false
      unscanned_items.each do |item|
        if item['product_type'] == 'individual'
          barcode_found = do_if_product_type_is_individual([item, clean_input, serial_added, clicked, barcode_found])
        elsif item['product_type'] == 'single'
          barcode_found = do_if_product_type_is_single([item, clean_input, serial_added, clicked, barcode_found])
        end
        break if barcode_found
      end
      barcode_found
    end

  end # class end
end #module end
