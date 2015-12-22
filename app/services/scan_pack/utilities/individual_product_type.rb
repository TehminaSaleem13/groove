module ScanPack::Utilities::IndividualProductType
  def do_if_product_type_is_individual(params)
    item, clean_input, serial_added, clicked, barcode_found = params
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
    barcode_found
  end
end