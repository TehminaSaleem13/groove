# frozen_string_literal: true

module ScanPack
  module ProductFirstScan
    module ToteScanHelper
      def run_assigned_to_tote
        if tote.order != order
          @result[:status] = false
          @result[:error_messages] = "Whoops! The #{tote_identifier} is already assigned. Please clear the #{tote_identifier} for the order from Orders List and try again."
        elsif valid_tote
          if tote.save
            order.touch(:last_suggested_at)
            order_item.process_item(nil, current_user.username, 1, nil)
            order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
            order.addactivity("#{tote_identifier} #{tote.name} assignment confirmed with #{tote_identifier} scan.", current_user.name)
            order.addactivity("Product with barcode: #{params[:barcode_input]} and sku: #{order_item.product.primary_sku} scanned", current_user.name)
            tote.reset_pending_order
            @result[:success_messages] = "#{order.increment_id} is successfully assigned to #{tote_identifier}: #{tote.name}"
          end
        else
          set_wrong_tote
        end
      end

      def run_put_in_tote
        if valid_tote
          order.touch(:last_suggested_at)
          order_item.process_item(nil, current_user.username, 1, nil)
          order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
          order.addactivity("Product with barcode: #{params[:barcode_input]} and sku: #{order_item.product.primary_sku} scanned", current_user.name)
          tote.reset_pending_order
          @result[:success_messages] = "#{order_item.product.name} is successfully scanned to #{tote_identifier}: #{tote.name}"
        else
          set_wrong_tote
        end
      end

      def run_scan_tote_to_complete
        if order.status == 'scanned'
          @result[:status] = false
          @result[:error_messages] = "Order ##{order.increment_id} is already scanned"
        elsif valid_tote
          order_item.process_item(nil, current_user.username, 1, nil)
          order.order_activities.last.destroy if order.order_activities.last.present? && (order.order_activities.last.action.include? 'setting the order PENDING')
          order.addactivity("Product with barcode: #{params[:barcode_input]} and sku: #{order_item.product.primary_sku} scanned", current_user.name)
          order.set_order_to_scanned_state(current_user.username)
          order.touch(:last_suggested_at)
          @result[:success_messages] = "#{order.increment_id} is successfully scanned"
          @result[:scan_tote_to_completed] = true
          @result[:multi_item_order_message] = scanpack_setting.multi_item_order_complete_msg
          @result[:multi_item_order_message_time] = scanpack_setting.multi_item_order_complete_msg_time
          @result[:store_type] = order.store.store_type
          @result[:popup_shipping_label] = order.store&.shipping_easy_credential&.popup_shipping_label
          @result[:order_cup_direct_shipping] = order.order_cup_direct_shipping
          @result[:large_popup] = order.store&.shipping_easy_credential&.large_popup
          @result[:multiple_lines_per_sku_accepted] = order.store&.shipping_easy_credential&.multiple_lines_per_sku_accepted
          ScanPack::ScanBarcodeService.new(current_user, {}, params).generate_order_barcode_slip(order) if scanpack_setting.post_scanning_option == 'Barcode' && !@result[:popup_shipping_label]
          @result[:order_items_scanned] = order.get_scanned_items.select { |item| item['qty_remaining'] == 0 }
          @result[:order_items_unscanned] = []
          @result[:order_items_partial_scanned] = []
          @result[:tote_name_identifier] = tote_identifier + ' ' + tote.name
          @result[:order] = order
          tote.release_order
        else
          set_wrong_tote
        end
      end
    end
  end
end
