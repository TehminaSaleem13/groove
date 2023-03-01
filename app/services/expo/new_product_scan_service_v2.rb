# frozen_string_literal: true

module Expo
  class NewProductScanServiceV2 < ScanPack::Base
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
      product_scan(clicked, serial_added)
      @result
    end

    def product_scan(clicked, serial_added)
      if clicked
        @single_order.clicked_scanned_qty = @single_order.clicked_scanned_qty.to_i + 1
        @single_order.save
      end

      do_if_restart_code_and_service_issue_code_not_enabled(clicked, serial_added)
      do_if_single_order_present if @single_order.present?

      @result
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
          value = check_scanning_item(unscanned_items, clean_input)
          if value
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

    def do_if_single_order_present
      @single_order.packing_user_id = @current_user.id
      set_error_messages("Could not save order with id: #{@single_order.id}") unless @single_order.save
    end

    def do_if_single_order_has_unscanned_items(clean_input, serial_added, clicked)
      @single_order.should_the_kit_be_split(clean_input) if @single_order.contains_kit && @single_order.contains_splittable_kit

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
