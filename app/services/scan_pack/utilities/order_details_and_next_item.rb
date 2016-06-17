module ScanPack
  module Utilities
    module OrderDetailsAndNextItem
      ######### ORDER DETAILS AND NEXT ITEM #############
      #-------------------------------------------------
      def order_details_and_next_item
        @single_order.reload
        data = @single_order.attributes
        data['next_item'] = {}
        data['unscanned_items'] = @single_order.get_unscanned_items
        data['scanned_items'] = @single_order.get_scanned_items
        do_if_unscanned_items_present(data) unless data['unscanned_items'].length == 0
        return data
      end

      def do_if_unscanned_items_present(data)
        most_recent_scanned_product = @session[:most_recent_scanned_product]
        if most_recent_scanned_product.present?
          do_check_unscanned_items_for_next_item(data, most_recent_scanned_product)
        end
        do_if_next_item_still_not_present(data) unless data['next_item'].present?
        data['next_item']['qty'] = data['next_item']['scanned_qty'] + data['next_item']['qty_remaining']
      end

      def do_check_unscanned_items_for_next_item(data, scanned_product_id)
        data['unscanned_items'].each_with_index do |unscanned_item, idx|
          product_type = unscanned_item['product_type']
          data['next_item'] = do_get_next_item(data, scanned_product_id, unscanned_item, product_type)

          next unless data['next_item'].present?

          data['unscanned_items'].insert(0, data['unscanned_items'].delete_at(idx))
          break
        end
      end

      def do_get_next_item(data, scanned_product_id, unscanned_item, product_type)
        session_parent_order_item = @session[:parent_order_item]
        unscanned_item_child_items = unscanned_item['child_items']

        case
        when session_parent_order_item && session_parent_order_item == unscanned_item['order_item_id']
          @session[:parent_order_item] = false
          item = if product_type == 'individual' && !unscanned_item_child_items.empty?
                   unscanned_item_child_items.first.clone
                 else
                   unscanned_item.clone
                 end
          return item
        when (
            product_type == 'single' &&
            scanned_product_id == unscanned_item['product_id'] &&
            unscanned_item['scanned_qty'] + unscanned_item['qty_remaining'] > 0
          )
          return unscanned_item.clone
        when product_type == 'individual'
          return do_find_next_item_in_child_items(unscanned_item_child_items, scanned_product_id)
        end
      end

      def do_find_next_item_in_child_items(unscanned_item_child_items, scanned_product_id)
        unscanned_item_child_items.each do |child_item|
          if child_item['product_id'] == scanned_product_id
            return child_item.clone
          end
        end
        return nil # to avoid returning unscanned_item_child_items
      end

      def do_if_next_item_still_not_present(data)
        unscanned_items = data['unscanned_items']
        product_type = unscanned_items.first['product_type']
        data['next_item'] = if product_type == 'single'
          unscanned_items.first.clone
        elsif product_type == 'individual' && unscanned_items.first['child_items'].present?
          unscanned_items.first['child_items'].first.clone
        else
          {'qty' => 0, 'scanned_qty' => 0, 'qty_remaining' => 0 }
        end
      end
      #--------END of ORDER DETAILS AND NEXT ITEM-----------------------------

    end
  end
end
