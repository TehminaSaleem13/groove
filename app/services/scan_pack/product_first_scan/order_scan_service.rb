# frozen_string_literal: true

module ScanPack
  module ProductFirstScan
    class OrderScanService < ScanPack::ProductFirstScan::Base
      include ScanPack::ProductFirstScan::OrderScanHelper

      def initialize(*args)
        super
      end

      def run
        @result[:status] = false

        unless product.present?
          @result[:notice_messages] = 'Sorry, no new orders can be found that require that item. Please check that all orders have been imported. If this is a new item that may not have the barcode saved you can search for the item by SKU in the products section and add it.'
          @result[:product_error] = true
        end

        return @result if @result[:product_error]

        # An item is scanned. The oldest single item order containing that item is found in our DB, the order is marked scanned, the post scanning call to ShippingEasy webhook is fired. Labels Print.
        order = Order.where("status = 'awaiting'").where('(SELECT COUNT(*) FROM order_items WHERE order_items.order_id = orders.id) = 1').joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).group(:id).having('SUM(order_items.qty) = 1').order('order_placed_time ASC').readonly(false).first

        return @result if order.present? && run_if_single_item_order_found(order, product)

        # If no single item orders are found with that item then all orders that have been assigned to a tote are searched to see if the item is required. If any toted orders require that item a check is done to see if that item completes any of the orders.
        orders = Order.includes([:tote]).where("orders.id IN (?) AND status = 'awaiting'", Tote.all.map(&:order_id).compact).joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).reject { |o| o.id.in? Tote.where(pending_order: true).pluck(:order_id).compact }
        if orders.any?
          can_complete_orders = orders.select { |o| o.get_unscanned_items(limit: nil).count == 1 && o.get_unscanned_items[0]['qty_remaining'] == 1 }
          if can_complete_orders.any?
            # If so, the user is prompted to scan the tote number that was assigned to the completed order. The user is notified that the order is Done. The order is marked Scanned and the webhook will be called to print the labels.
            run_if_can_complete_any_order(can_complete_orders, product)
          else
            # If the item is required in a toted order but does not complete the order then the item will be assigned to the lowest-numbered tote requiring the item and that tote number will be prompted for scanning. After it is scanned GP will prompt the user for the next product scan.
            run_if_can_not_complete_any_order(orders, product)
          end
          return @result
        end

        # If the item is not required in any toted orders, the oldest multi-item order requiring the item is found in our DB.
        order = Order.where("status = 'awaiting'").joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).order('order_placed_time ASC').reject { |o| o.id.in? Tote.where(pending_order: true).pluck(:order_id).compact }.first
        available_tote = Tote.where(order_id: order.id, pending_order: false).first if order.present?
        available_tote = Tote.order('number ASC').where(order_id: nil, pending_order: false).first unless available_tote.try(:present?)
        tote_set = ToteSet.last || ToteSet.create(name: 'T')
        available_tote = tote_set.totes.create(name: "T-#{Tote.all.count + 1}", number: Tote.all.count + 1) if Tote.all.count < tote_set.max_totes && !available_tote

        if order.present? && available_tote.present?
          # The lowest available open tote number is displayed and we wait for the user to scan the number. Once scanned, the order is assigned to that tote and we record that the item is scanned into that tote.
          run_if_oldest_multi_item_order_found(order, product, available_tote)
          return @result
        end

        @result[:no_order] = true

        orders = Order.where(status: 'onhold').joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id)
        if orders.any?
          # If there are no multi-item orders with the Awaiting Status requiring the item then Action Required orders will be checked. If one is found we will give the following notification
          # The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List
          @result[:notice_messages] = 'The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List'
        else
          pending_order = Order.includes(%i[tote order_items]).where("orders.id IN (?) AND status = 'awaiting'", tote_set.totes.all.map(&:order_id).compact).joins(:order_items).where("order_items.scanned_status != 'scanned' AND order_items.product_id = ?", product.id).reject { |o| o.id.in? tote_set.totes.where(pending_order: false).pluck(:order_id).compact }.first
          if pending_order
            run_if_pending_order(pending_order, product)
            @result[:unscanned_items] = pending_order.get_unscanned_items if params['app'].present?
          else
            # If there are no open orders requiring the item that was scanned we will alert the user: Sorry, no orders require that item.
            @result[:notice_messages] = 'Sorry, no orders can be found that require that item. Please check that all orders have been imported. If this is a new item that may not have the barcode saved you can search for the item by SKU in the products section and add it.'
          end
        end
        @result
      end

      private

      def input
        @input ||= params[:input]
      end

      def product
        @product ||= Product.joins(:product_barcodes).where(product_barcodes: { barcode: input }).first
      end
    end
  end
end
