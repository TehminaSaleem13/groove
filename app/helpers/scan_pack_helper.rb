module ScanPackHelper
  def process_product_scan (params, result)
		barcode_found = false
		@order.order_items.each do |order_item|
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
		end

	  result
  end
  
end
