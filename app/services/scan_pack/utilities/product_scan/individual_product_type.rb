module ScanPack::Utilities::ProductScan::IndividualProductType
  def do_if_product_type_is_individual(params)
    item, clean_input, serial_added, clicked, barcode_found = params
    item['child_items'].each do |child_item|
      if child_item['barcodes'].present?
        barcode_found = do_if_child_item_has_barcodes(params, child_item)
      end
      break if barcode_found
    end
    barcode_found
  end

  def do_if_child_item_has_barcodes(params, child_item)
    item, clean_input, serial_added, clicked, barcode_found = params
    child_item['barcodes'].each do |barcode|
      if barcode.barcode.strip.downcase == clean_input.downcase || (
        @scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && child_item['skippable']
        )
        barcode_found = true
        #process product barcode scan
        order_item_kit_product = OrderItemKitProduct.find(child_item['kit_product_id'])
        order_item = order_item_kit_product.order_item if order_item_kit_product.order_item.present?

        #do_if_serial_not_added(order_item_kit_product) unless serial_added
        # from LotNumber Module
        store_lot_number(order_item, serial_added)
        
        do_if_order_item_kit_product_present(
          [item, child_item, serial_added, clicked, order_item_kit_product]
          ) if order_item_kit_product.present?

        break
      end
    end
    barcode_found
  end

  # def do_if_serial_not_added(order_item_kit_product)
  #   order_item = order_item_kit_product.order_item unless order_item_kit_product.order_item.nil?
  #   @result['data']['serial']['order_item_id'] = order_item.id
  #   if @scanpack_settings.record_lot_number
  #     lot_number = calculate_lot_number
  #     product = order_item.product if order_item.present? || order_item.product.present?
      
  #     # unless lot_number.nil?
  #     #   product_lots = product.product_lots
  #     #   product_lot = product_lots.where(lot_number: lot_number).first || product_lots.create(lot_number: lot_number)
  #     #   OrderItemOrderSerialProductLot.create(order_item_id: order_item.id, product_lot_id: product_lot.id, qty: 1)
  #     #   @result['data']['serial']['product_lot_id'] = product_lot.id
  #     # else
  #     #   @result['data']['serial']['product_lot_id'] = nil
  #     # end
  #     @result['data']['serial']['product_lot_id'] = lot_number.present? ?
  #                                                 do_if_lot_number_present(order_item, product, lot_number) : nil
  #   else
  #     @result['data']['serial']['product_lot_id'] = nil
  #   end
  # end

  def do_if_order_item_kit_product_present(params)
    item, child_item, serial_added, clicked, order_item_kit_product = params
    child_item_product_id = child_item['product_id']
    if child_item['record_serial']
      do_if_child_item_record_serial(params)
    else
      order_item_kit_product.process_item(clicked, @current_user.username)
      (@session[:most_recent_scanned_products] ||= []) << child_item_product_id
      @session[:parent_order_item] = item['order_item_id']
    end
  end

  def do_if_child_item_record_serial(params)
    item, child_item, serial_added, clicked, order_item_kit_product = params
    if serial_added
      order_item_kit_product.process_item(clicked, @current_user.username)
      (@session[:most_recent_scanned_products] ||= []) << child_item_product_id
      @session[:parent_order_item] = item['order_item_id']
    else
      @result['data']['serial']['ask'] = true
      @result['data']['serial']['product_id'] = child_item_product_id
    end
  end

end #module