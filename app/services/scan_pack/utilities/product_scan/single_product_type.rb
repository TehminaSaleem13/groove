module ScanPack::Utilities::ProductScan::SingleProductType
  def do_if_product_type_is_single(params)
    item, clean_input, serial_added, clicked, barcode_found = params
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

          process_scan(clicked, order_item, serial_added)

          # If the product was skippable and CODE is SKIP
          # then we can remove that order_item from the order
          if @scanpack_settings.skip_code_enabled? && clean_input == @scanpack_settings.skip_code && item['skippable']
            remove_skippable_product(item)
          end
          break
        end
      else
        if barcode.barcode == clean_input
          barcode_found = true
          order_item = OrderItem.find(item['order_item_id'])
          process_scan(clicked, order_item, serial_added)
        end
      end
    end
    barcode_found
  end

  # Remove those order_items that are skippable when the scanned barcode
  # is SKIP entered as the barcode.
  def remove_skippable_product(item)
    order_item = OrderItem.find(item['order_item_id'])
    order = order_item.order
    order.order_items.delete(order_item)
    order.save
  end
end
