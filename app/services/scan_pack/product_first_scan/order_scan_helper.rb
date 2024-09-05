# frozen_string_literal: true

module ScanPack
  module ProductFirstScan
    module OrderScanHelper
      def run_if_single_item_order_found(order, product)
        order_item = order.order_items.where(product_id: product.id).first
        order.update(last_suggested_at: DateTime.now.in_time_zone)
        order_item.process_item(nil, current_user.username, 1, nil)
        order.addactivity("Product with barcode: #{input} and sku: #{order_item.product.primary_sku} scanned", current_user.name)
        order.set_order_to_scanned_state(current_user.username)
        @result[:single_item_order] = true
        @result[:status] = true
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:store_type] = order.store.store_type
        @result[:single_item_order_message] = scanpack_setting.single_item_order_complete_msg
        @result[:single_item_order_message_time] = scanpack_setting.single_item_order_complete_msg_time
        @result[:popup_shipping_label] = order.store&.shipping_easy_credential&.popup_shipping_label
        @result[:order_cup_direct_shipping] = order.order_cup_direct_shipping
        @result[:large_popup] = order.store&.shipping_easy_credential&.large_popup
        @result[:multiple_lines_per_sku_accepted] = order.store&.shipping_easy_credential&.multiple_lines_per_sku_accepted
        ScanPack::ScanBarcodeService.new(current_user, {}, params).generate_order_barcode_slip(order) if scanpack_setting.post_scanning_option == 'Barcode' && !@result[:popup_shipping_label]
      end

      def run_if_can_complete_any_order(can_complete_orders, product)
        @result[:scan_tote_to_complete] = true
        tote = can_complete_orders.map(&:tote).min_by(&:number)
        order = tote.order
        order_item = OrderItem.find(order.get_unscanned_items(limit: nil).first['order_item_id'])
        @result[:tote] = tote
        @result[:tote_identifier] = tote_identifier
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:order_item] = order_item
        @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
        @result[:order_items_unscanned] = []
        @result[:order_items_partial_scanned] = []
        current_item = order.get_unscanned_items(limit: nil).select { |item| item['order_item_id'] == order_item.id }.first
        tote.update(order_id: order.id, pending_order: true)
        current_item['scanned_qty'] = begin
                                        (current_item['scanned_qty'] + 1)
                                      rescue StandardError
                                        nil
                                      end
        current_item['qty_remaining'] = begin
                                          (current_item['qty_remaining'] - 1)
                                        rescue StandardError
                                          nil
                                        end
        @result[:barcode_input] = input
        order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{tote.name}.", @current_user.name)
        @result[:order_items_scanned] << current_item
        @result[:status] = true
      end

      def run_if_can_not_complete_any_order(orders, product)
        tote = orders.map(&:tote).min_by(&:number)
        @result[:put_in_tote] = true
        order = tote.order
        order_item = order.order_items.where(product_id: product.id).first
        @result[:tote] = tote
        @result[:tote_identifier] = tote_identifier
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:order_item] = order_item
        @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
        @result[:order_items_unscanned] = order.get_unscanned_items(limit: nil).select { |item| item['scanned_qty'] == 0 && item['order_item_id'] != order_item.id }
        @result[:order_items_partial_scanned] = order.get_unscanned_items(limit: nil).select { |item| item['scanned_qty'] != 0 && item['order_item_id'] != order_item.id }
        current_item = order.get_unscanned_items(limit: nil).select { |item| item['order_item_id'] == order_item.id }.first
        tote.update(order_id: order.id, pending_order: true)
        current_item['scanned_qty'] = begin
                                        current_item['scanned_qty'] + 1
                                      rescue StandardError
                                        nil
                                      end
        current_item['qty_remaining'] = (current_item['qty_remaining'] || 0) - 1
        current_item['qty_remaining'] > 0 ? @result[:order_items_partial_scanned] << current_item : @result[:order_items_scanned] << current_item
        order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{tote.name}.", @current_user.name)
        @result[:barcode_input] = input
        @result[:status] = true
      end

      def run_if_oldest_multi_item_order_found(order, product, available_tote)
        order_item = order.order_items.where(product_id: product.id).first
        @result[:assigned_to_tote] = true
        product_first_scan_order_hash(product, order, order_item, available_tote)
        current_item = order.get_unscanned_items(limit: nil).select { |item| item['order_item_id'] == order_item.id }.first
        current_item['scanned_qty'] = begin
                                        current_item['scanned_qty'] + 1
                                      rescue StandardError
                                        nil
                                      end
        current_item['qty_remaining'] = (current_item['qty_remaining'] || 0) - 1
        current_item['qty_remaining'] > 0 ? @result[:order_items_partial_scanned] << current_item : @result[:order_items_scanned] << current_item
        @result[:barcode_input] = input
        order.addactivity("Barcode #{input} was scanned for SKU #{@result[:barcode]} setting the order PENDING in #{@result[:tote_identifier]} #{available_tote.name}.", @current_user.name)
        @result[:status] = true
        available_tote.update(order_id: order.id, pending_order: true)
      end

      def run_if_pending_order(pending_order, product)
        @result[:no_order] = false
        @result[:pending_order] = true
        product_first_scan_order_hash(product, pending_order, pending_order.order_items.where(product_id: product.id).first, pending_order.tote)
        @result[:can_complete_order] = pending_order.get_unscanned_items(limit: nil).count == 1 && pending_order.get_unscanned_items[0]['qty_remaining']
        @result[:tote_identifier] = tote_identifier + ' ' + @result[:tote].name
        @result[:barcode_input] = input
      end

      private

      def product_first_scan_order_hash(product, order, order_item, tote)
        @result[:tote] = tote
        @result[:tote_identifier] = tote_identifier
        @result[:product] = product
        @result[:barcode] = product.primary_sku
        @result[:order] = order
        @result[:order_item] = order_item
        @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
        @result[:order_items_unscanned] = order.get_unscanned_items(limit: nil).select { |item| item['scanned_qty'] == 0 && item['order_item_id'] != order_item.id }
        @result[:order_items_partial_scanned] = order.get_unscanned_items(limit: nil).select { |item| item['scanned_qty'] != 0 && item['order_item_id'] != order_item.id }
      end
    end
  end
end
