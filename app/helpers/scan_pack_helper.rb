module ScanPackHelper
  def process_product_scan (params, result)
		barcode_found = false
    order = Order.find(params[:order_id])
		order.order_items.each do |order_item|
      product = Product.find_by_id(order_item.product_id)
			unless product.nil?
        barcodes = product.product_barcodes.where(:barcode=>params[:barcode])
        if barcodes.length > 0
          barcode_found = true
          if order_item.scanned_status == 'scanned' || order_item.scanned_qty >= order_item.qty
            result['status'] &= false
            result['error_messages'].push("This item has already been scanned, Please scan another item")
          else
            order_item.scanned_qty = order_item.scanned_qty + 1
            if order_item.scanned_qty == order_item.qty
              order_item.scanned_status = 'scanned'
            else
              order_item.scanned_status = 'partially_scanned'
            end
            order_item.save
            puts order_item.scanned_status
          end
          unless @order.has_unscanned_items
             @order.set_order_to_scanned_state
             result['data']['next_state'] = 'ready_for_order'
          end
          break
        end
			end
		end
		unless barcode_found
			result['status'] &= false
			result['error_messages'].push("There are no barcodes that match items in this order")
      puts "Barcode not found"
		end

	  result
  end

  def process_product_scan_for_kits(params, result)
    barcode_found = false
    order = Order.find(params[:order_id])
    order.order_items.each do |order_item|
      product = Product.find_by_id(order_item.product_id)

      if !product.nil? && product.is_kit
        
        product.product_kit_skuss.each do |kit_item|
          kit_item.product.product_barcodes.each do |barcode|
            if barcode.barcode == params[:barcode]
              barcode_found = true
              break
            end
          end
        end

        if barcode_found
          if order_item.scanned_status == 'scanned' || order_item.scanned_qty >= order_item.qty
            result['status'] &= false
            result['error_messages'].push("This item has already been scanned, Please scan another item")
          else
            order_item.order_item_kit_products.each do |order_item_kit_product|
              order_item_kit_product.scanned_qty = order_item_kit_product.scanned_qty + 1
              if order_item_kit_product.scanned_qty == order_item.qty
                order_item_kit_product.scanned_status = 'scanned'
              else
                order_item_kit_product.scanned_status = 'partially_scanned'
              end
              order_item_kit_product.save
            end

            if order_item.has_unscanned_kit_items
              if order_item.has_atleast_one_item_scanned
                order_item.scanned_status = 'kit_partially_scanned'
              end
            else
              order_item.scanned_qty = order_item.scanned_qty + 1
              order_item.scanned_status = 'scanned'
            end
            order_item.save
          end

          unless @order.has_unscanned_items
             @order.set_order_to_scanned_state
             result['data']['next_state'] = 'ready_for_order'
          end
        end
      end

    unless barcode_found
      result['status'] &= false
      result['error_messages'].push("There are no barcodes that match items in this order")
      puts "Barcode not found"
    end

    result
  end

end
