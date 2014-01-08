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
          unless order.has_unscanned_items
             order.set_order_to_scanned_state
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

  # def process_product_scan_for_kits(params, result)
  #   barcode_found = false
  #   matched_product_kit_sku_id = 0
  #   order = Order.find(params[:order_id])
    
  #   order.order_items.each do |order_item|
  #   product = Product.find_by_id(order_item.product_id)

  #   #check if barcode matches for any of the non-scanned items in the order
  #   #to determine non scanned items in the order, check the non scanned order items
  #   #for each order item, if product is kit and kit_parsing method is individual, then 
  #   #for each order item kit product, if barcode matches the product barcode, then mark
  #   #the barcode found as true and do processing
  #   if order_item.scanned_status != 'scanned' && !product.nil? && 
  #       product.is_kit && product.kit_parsing == 'individual'
      
  #     order_item.order_item_kit_products.each do |kit_product|
  #       if kit_product.scanned_status != 'scanned'
  #         item_barcodes = kit_product.product_kit_skus.product.product_barcodes
  #         item_barcodes.each do |barcode|
  #           if barcode.barcode == params[:barcode]
  #             barcode_found  = true
  #             #if barcode exists then process the barcode for scan
              
  #             #to process barcode for scan, find the first item which matches the non scanned item barcode
  #               #increment the scanned qty for the order item which is scanned in the order item kit products
                
  #               #if scanned qty is same as product quantity (obtained from product_kit_skus model) then mark 
  #               #order item kit product as scanned
                
  #               #if all order item kit products are scanned, then mark the order item as scanned depending on
  #               #scanned qty, increment the scanned qty in the order item

  #               #if all order items are scanned, then mark order as scanned              
  #           end
  #         end
  #       end
  #     end




  #   #if barcode exists then process the barcode for scan
  #     #to process barcode for scan, find the first item which matches the non scanned item barcode
  #     #increment the scanned qty for the order item which is scanned in the order item kit products
      
  #     #if scanned qty is same as product quantity (obtained from product_kit_skus model) then mark 
  #     #order item kit product as scanned
      
  #     #if all order item kit products are scanned, then mark the order item as scanned depending on
  #     #scanned qty, increment the scanned qty in the order item

  #     #if all order items are scanned, then mark order as scanned


  #   #product_kit_sku = 
  #   if order_item.scanned_status != 'scanned' && !product.nil? && product.is_kit
  #     product.product_kit_skuss.each do |kit_item|
  #       kit_item.product.product_barcodes.each do |barcode|
  #         #check for order item product kit
  #         if barcode.barcode == params[:barcode]
  #           barcode_found = true
  #           matched_product_kit_sku_id = kit_item.id
  #           break
  #         end
  #       end
  #     end

  #     if barcode_found
  #       if order_item.scanned_status == 'scanned' || order_item.scanned_qty >= order_item.qty
  #         result['status'] &= false
  #         result['error_messages'].push("This item has already been scanned, Please scan another item")
  #       else
  #         order_item.order_item_kit_products.each do |order_item_kit_product|
  #           if order_item_kit_product.product_kit_skus.id == matched_product_kit_sku_id
  #             if order_item_kit_product.scanned_qty < order_item_kit_product.product_kit_skus.qty
  #               order_item_kit_product.scanned_qty = order_item_kit_product.scanned_qty + 1
  #               if order_item_kit_product.scanned_qty == order_item_kit_product.product_kit_skus.qty
  #                 order_item_kit_product.scanned_status = 'scanned'
  #               else
  #                 order_item_kit_product.scanned_status = 'partially_scanned'
  #               end
  #               order_item_kit_product.save
  #             else
  #               result['status'] &= false
  #               result['error_messages'].push("All items in this product are already scanned")
  #             end
  #           end
  #         end

  #         if order_item.has_unscanned_kit_items
  #           if order_item.has_atleast_one_item_scanned
  #             order_item.scanned_status = 'kit_partially_scanned'
  #           end
  #         else
  #           order_item.scanned_qty = order_item.scanned_qty + 1
  #           if order_item.scanned_qty >= order_item.qty
  #             order_item.scanned_status = 'scanned'
  #           else
  #             order_item.scanned_status = 'partially_scanned'
  #           end
  #         end
  #         order_item.save
  #         break
  #       end
  #     end
  #   end

  #   #update order state
  #   unless order.has_unscanned_items
  #      order.set_order_to_scanned_state
  #      result['data']['next_state'] = 'ready_for_order'
  #   end

  #   #if barcode not found
  #   unless barcode_found
  #     result['status'] &= false
  #     result['error_messages'].push("There are no barcodes that match items in this order")
  #     puts "Barcode not found"
  #   end
  # end
  #   result
  # end

end
