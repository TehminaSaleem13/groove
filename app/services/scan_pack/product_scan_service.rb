module ScanPack
  class ProductScanService < ScanPack::Base
    include ScanPack::Utilities::LotNumber
    include ScanPack::Utilities::ProcessScan
    
    def initialize(service_params)
      @current_user, @session, @input, @state, @id = service_params
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
      @scanpack_settings = ScanPackSetting.all.first
    end

    def run(clicked, serial_added)
      case true
      when @id.blank? && @input.blank?
        set_error_messages('Please specify barcode and order id to confirm purchase code')
      when @single_order.blank?
        set_error_messages('Could not find order with id:'+@id)
      else
        product_scan(clicked, serial_added)
      end
      @result
    end

    def set_error_messages(error_message)
      @result['status'] &= false
      @result['error_messages'].push(error_message)
    end

    def product_scan(clicked, serial_added)
      if @scanpack_settings.restart_code_enabled? && @input == @scanpack_settings.restart_code
        do_if_restart_code_is_enabled_and_and_eql_to_input
      elsif @scanpack_settings.service_issue_code_enabled? && @input == @scanpack_settings.service_issue_code
        do_if_service_issue_code_is_enabled_and_and_eql_to_input
      else
        escape_string = ''
        if @scanpack_settings.escape_string_enabled && !@input.index(@scanpack_settings.escape_string).nil?
          clean_input = @input.slice(0..(@input.index(@scanpack_settings.escape_string)-1))
        else
          clean_input = @input
        end

        @result['data']['serial']['clicked'] = clicked
        @result['data']['serial']['barcode'] = clean_input
        @result['data']['serial']['order_id'] = @id

        @result['data']['order_num'] = @single_order.increment_id

        if @single_order.has_unscanned_items
          @single_order.should_the_kit_be_split(clean_input) if @single_order.contains_kit && @single_order.contains_splittable_kit

          if @single_order.last_suggested_at.nil?
            @single_order.last_suggested_at = DateTime.now
            @single_order.save
          end
          unscanned_items = @single_order.get_unscanned_items
          barcode_found = false
          #search if barcode exists
          unscanned_items.each do |item|
            if item['product_type'] == 'individual'
              if item['child_items'].length > 0
                item['child_items'].each do |child_item|
                  if !child_item['barcodes'].nil?
                    child_item['barcodes'].each do |barcode|
                      if barcode.barcode.strip.downcase == clean_input.downcase || (@scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && child_item['skippable'])
                        barcode_found = true
                        #process product barcode scan
                        order_item_kit_product =
                          OrderItemKitProduct.find(child_item['kit_product_id'])

                        unless serial_added
                          order_item = order_item_kit_product.order_item unless order_item_kit_product.order_item.nil?
                          @result['data']['serial']['order_item_id'] = order_item.id
                          if @scanpack_settings.record_lot_number
                            lot_number = calculate_lot_number
                            product = order_item.product unless order_item.nil? || order_item.product.nil?
                            unless lot_number.nil?
                              if product.product_lots.where(lot_number: lot_number).empty?
                                product.product_lots.create(product_id: product.id, lot_number: lot_number)
                              end
                              product_lot = product.product_lots.where(lot_number: lot_number).first
                              OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
                              @result['data']['serial']['product_lot_id'] = product_lot.id
                            else
                              @result['data']['serial']['product_lot_id'] = nil
                            end
                          else
                            @result['data']['serial']['product_lot_id'] = nil
                          end
                        end

                        unless order_item_kit_product.nil?
                          if child_item['record_serial']
                            if serial_added
                              order_item_kit_product.process_item(clicked, @current_user.username)
                              (@session[:most_recent_scanned_products] ||= []) << child_item['product_id']
                              @session[:parent_order_item] = item['order_item_id']
                            else
                              @result['data']['serial']['ask'] = true
                              @result['data']['serial']['product_id'] = child_item['product_id']
                            end
                          else
                            order_item_kit_product.process_item(clicked, @current_user.username)
                            (@session[:most_recent_scanned_products] ||= []) << child_item['product_id']
                            @session[:parent_order_item] = item['order_item_id']

                          end
                        end

                        break
                      end
                    end
                  end
                  break if barcode_found
                end
              end
            elsif item['product_type'] == 'single'
              item['barcodes'].each do |barcode|
                if barcode.barcode.strip.downcase == clean_input.strip.downcase || (@scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && item['skippable'])
                  barcode_found = true
                  #process product barcode scan
                  order_item = OrderItem.find(item['order_item_id'])

                  unless serial_added
                    @result['data']['serial']['order_item_id'] = order_item.id
                    if @scanpack_settings.record_lot_number
                      lot_number = calculate_lot_number
                      product = order_item.product unless order_item.product.nil?
                      unless lot_number.nil?
                        if product.product_lots.where(lot_number: lot_number).empty?
                          product.product_lots.create(lot_number: lot_number)
                        end
                        product_lot = product.product_lots.where(lot_number: lot_number).first
                        OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
                        @result['data']['serial']['product_lot_id'] = product_lot.id
                      else
                        @result['data']['serial']['product_lot_id'] = nil
                      end
                    else
                      @result['data']['serial']['product_lot_id'] = nil
                    end
                  end

                  process_scan(clicked, order_item, serial_added)
                  # If the product was skippable and CODE is SKIP
                  # then we can remove that order_item from the order
                  if @scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && item['skippable']
                    remove_skippable_product(item)
                  end
                  break
                end
              end
            end
            break if barcode_found
          end

          unless barcode_found
            product_barcodes = ProductBarcode.where(barcode: clean_input)
            unless product_barcodes.empty?
              product_barcode = product_barcodes.first
              product = product_barcode.product unless product_barcode.product.nil?
              unless product.nil?
                if product.add_to_any_order
                  barcode_found = true
                  # check if the item is part of the order item list or not
                  #IF the item is already in the items list, then just increment the qty for the item
                  # if the item is not in the items list, then add the item to the list.Add activities
                  item_in_order = false
                  @single_order.order_items.each do |item|
                    if item.product == product
                      store_lot_number(item, serial_added)
                      item.qty += 1
                      item.scanned_status = 'partially_scanned'
                      item.save
                      @single_order.addactivity("Item with SKU: #{item.sku} Added", @current_user.username)
                      item_in_order = true
                      process_scan(clicked, item, serial_added)
                      break
                    end
                  end
                  unless item_in_order
                    @single_order.add_item_to_order(product)
                    order_items = @single_order.order_items.where(product_id: product.id)
                    order_item = order_items.first unless order_items.empty?
                    unless order_item.nil?
                      store_lot_number(order_item, serial_added)
                      @single_order.addactivity("Item with SKU: #{order_item.sku} Added", @current_user.username)
                      process_scan(clicked, order_item, serial_added)
                    end
                  end
                end
              end
            end
          end

          if barcode_found
            if !@single_order.has_unscanned_items
              if @scanpack_settings.post_scanning_option != "None"
                if @scanpack_settings.post_scanning_option == "Verify"
                  if @single_order.tracking_num.nil?
                    @result['data']['next_state'] = 'scanpack.rfp.no_tracking_info'
                    @single_order.addactivity("Tracking information was not imported with this order so the shipping label could not be verified ", @current_user.username)
                  else
                    @result['data']['next_state'] = 'scanpack.rfp.verifying'
                  end
                elsif @scanpack_settings.post_scanning_option == "Record"
                  @result['data']['next_state'] = 'scanpack.rfp.recording'
                elsif @scanpack_settings.post_scanning_option == "PackingSlip"
                  #generate packing slip for the order
                  @single_order.set_order_to_scanned_state(@current_user.username)
                  @result['data']['order_complete'] = true
                  @result['data']['next_state'] = 'scanpack.rfo'
                  generate_packing_slip(@single_order)
                else
                  #generate barcode for the order
                  @single_order.set_order_to_scanned_state(@current_user.username)
                  @result['data']['order_complete'] = true
                  @result['data']['next_state'] = 'scanpack.rfo'
                  generate_order_barcode_slip(@single_order)
                end
              else
                @single_order.set_order_to_scanned_state(@current_user.username)
                @result['data']['order_complete'] = true
                @result['data']['next_state'] = 'scanpack.rfo'
              end
            end
            @single_order.last_suggested_at = DateTime.now
          else
            @single_order.inaccurate_scan_count = @single_order.inaccurate_scan_count + 1
            @result['status'] &= false
            @result['error_messages'].push("Barcode '"+clean_input+"' doesn't match any item on this order")
          end
        else
          @result['status'] &= false
          @result['error_messages'].push("There are no unscanned items in this order")
        end
      end

      do_if_single_order_present if @single_order.present?

      return @result
    end

    def do_if_service_issue_code_is_enabled_and_and_eql_to_input
      if @single_order.status !='scanned'
        @single_order.reset_scanned_status
        @single_order.status = 'serviceissue'
        @result['data']['next_state'] = 'scanpack.rfo'
        @result['data']['ask_note'] = true
      else
        set_error_messages('Order with id: '+@id+' is already in scanned state')
      end
    end

    def do_if_restart_code_is_enabled_and_and_eql_to_input
      if @single_order.status != 'scanned'
        @single_order.reset_scanned_status
        @result['data']['next_state'] = 'scanpack.rfo'
      else
        set_error_messages('Order with id: '+@id.to_s+' is already in scanned state')
      end
    end

    def do_if_single_order_present
      @single_order.packing_user_id = @current_user.id
      unless @single_order.save
        set_error_messages('Could not save order with id: '+@single_order.id)
      end
      @result['data']['order'] = order_details_and_next_item
      @result['data']['scan_pack_settings'] = @scanpack_settings
    end
    
    # Remove those order_items that are skippable when the scanned barcode
    # is SKIP entered as the barcode.
    def remove_skippable_product item
      order_item = OrderItem.find(item['order_item_id'])
      order = order_item.order
      order.order_items.delete(order_item)
      order.save
    end
    
  end # class end
end #module end