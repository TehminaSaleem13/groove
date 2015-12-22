module ScanPack::Utilities::Barcode
  def do_if_barcode_not_found(clean_input, serial_added, clicked)
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
    barcode_found
  end

  def do_if_barcode_found
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
  end
end