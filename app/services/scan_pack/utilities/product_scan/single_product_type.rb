module ScanPack::Utilities::ProductScan::SingleProductType
  def do_if_product_type_is_single(params)
    item, clean_input, serial_added, clicked, barcode_found, type_scan = params
    item['barcodes'].each do |barcode|
      if GeneralSetting.all.first.master_switch == false
        if barcode.barcode.strip.downcase == clean_input.strip.downcase || (@scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && item['skippable'])
          barcode_found = true
          #process product barcode scan
          order_item = OrderItem.find(item['order_item_id'])

          # from LotNumber Module
          # store_lot_number(order_item, serial_added)

          # unless serial_added
          #   @result['data']['serial']['order_item_id'] = order_item.id
          #   if @scanpack_settings.record_lot_number
          #     lot_number = calculate_lot_number
          #     product = order_item.product unless order_item.product.nil?
          #     unless lot_number.nil?
          #       if product.product_lots.where(lot_number: lot_number).empty?
          #         product.product_lots.create(lot_number: lot_number)
          #       end
          #       product_lot = product.product_lots.where(lot_number: lot_number).first
          #       OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
          #       @result['data']['serial']['product_lot_id'] = product_lot.id
          #     else
          #       @result['data']['serial']['product_lot_id'] = nil
          #     end
          #   else
          #     @result['data']['serial']['product_lot_id'] = nil
          #   end
          # end

          # process_scan(clicked, order_item, serial_added)

          # If the product was skippable and CODE is SKIP
          # then we can remove that order_item from the order
          if @scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && item['skippable']
            qty = remove_skippable_product(item)
            order_item.update_attributes(skipped_qty: qty) unless @scanpack_settings.remove_skipped
            @single_order.order_items.delete(order_item) if @scanpack_settings.remove_skipped && order_item.scanned_status != 'partially_scanned'
            @single_order.addactivity("QTY #{qty} of SKU #{item['sku']} was skipped using the SKIP barcode", @current_user.try(:username))
          else
            store_lot_number(order_item, serial_added)
            process_scan(clicked, order_item, serial_added, type_scan)
          end
          break
        end
      else
        if barcode.barcode == clean_input
          barcode_found = true
          order_item = OrderItem.find(item['order_item_id'])
          process_scan(clicked, order_item, serial_added, type_scan)
        end
      end
    end
    barcode_found
  end

  # Remove those order_items that are skippable when the scanned barcode
  # is SKIP entered as the barcode.
  def remove_skippable_product(item)
    @single_order.order_activities.last.try(:destroy)
    order_item = OrderItem.find(item['order_item_id'])
    # qty = 0
    # if order_item.scanned_status == 'partially_scanned'
      qty = order_item.qty - order_item.scanned_qty
      order_item.qty = order_item.scanned_qty
      order_item.scanned_status = 'scanned'
      order_item.save
    # else
    #   qty = order_item.qty - order_item.scanned_qty
    #   order = order_item.order
    #   order.order_items.delete(order_item)
    #   order.save
    # end
    qty
  end

  def remove_kit_product_item_from_order(item)
    @single_order.order_activities.last.try(:destroy)
    order_item_kit_product = OrderItemKitProduct.find(item['kit_product_id'])
    order_item_kit_product.process_item(nil, @current_user.username, 1, true)
    remove_kit_item_from_order(item)
  end
end
