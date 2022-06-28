module Expo
  class NewProductScanService < ScanPack::Base
    include ScanPack::Utilities::ProductScan::LotNumber
    include ScanPack::Utilities::ProductScan::ProcessScan
    include ScanPack::Utilities::ProductScan::Barcode
    include ScanPack::Utilities::ProductScan::IndividualProductType
    include ScanPack::Utilities::ProductScan::SingleProductType

    def initialize(args)
      @current_user, @session, @input, @state, @id, @box_id, @typein_count = args
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
      product_scan(clicked, serial_added)
      @result
    end

    def product_scan(clicked, serial_added)

      if clicked
        @single_order.clicked_scanned_qty = @single_order.clicked_scanned_qty.to_i + 1
        @single_order.save
      end
      case
      when @scanpack_settings.restart_code_enabled? && @input == @scanpack_settings.restart_code
        do_if_restart_code_is_enabled_and_and_eql_to_input
      when @scanpack_settings.service_issue_code_enabled? && @input == @scanpack_settings.service_issue_code
        do_if_service_issue_code_is_enabled_and_and_eql_to_input
      when @scanpack_settings.remove_enabled? && @input == @scanpack_settings.remove_barcode
        do_if_remove_or_partial_code_is_enabled_and_and_eql_to_input('REMOVE')
      end
      do_if_single_order_present if @single_order.present?

      update_session

      return @result
    end

    def update_session
      return unless @result['data']['next_state'].eql?('scanpack.rfo')
      @session[:most_recent_scanned_product] = nil
    end

    def do_if_remove_or_partial_code_is_enabled_and_and_eql_to_input(code_type)
      if code_type == 'PARTIAL'
        @single_order.get_unscanned_items(limit: nil).each do |item|
          qty = remove_skippable_product(item)
          @single_order.addactivity("QTY #{qty} of SKU #{item['sku']} was removed using the PARTIAL barcode", @current_user.try(:username))
        end
      elsif code_type == 'REMOVE'
        item = @single_order.get_unscanned_items(limit: nil).first
        qty = item['product_type'] == 'individual' ? remove_kit_product_item_from_order(item['child_items'].first) : remove_skippable_product(item)
        @single_order.addactivity("QTY #{qty} of SKU #{item['product_type'] == 'individual' ? item['child_items'].first['sku'] : item['sku']} was removed using the REMOVE barcode", @current_user.try(:username))
      end
      # do_if_barcode_found
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
  end # class end
end #module end
