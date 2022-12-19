# frozen_string_literal: true

module Groovepacker
  module Inventory
    class Orders
      class << self
        include Groovepacker::Inventory::Helper

        def sell(order, update_allocated = true)
          return false unless inventory_tracking_enabled?

          result = true
          order.order_items.each do |order_item|
            result &= process_sell_item(order_item, 1, update_allocated)
          end
          result
        end

        def unsell(order)
          return false unless inventory_tracking_enabled?

          result = true
          order.order_items.each do |order_item|
            result &= process_sell_item(order_item, -1)
          end
          result
        end

        def allocate(order, status_match = false)
          return false unless inventory_tracking_enabled?

          result = true
          order.order_items.reload
          order.order_items.each do |order_item|
            result &= allocate_item(order_item, status_match)
          end
          result
        end

        def deallocate(order, status_match = false)
          return false unless inventory_tracking_enabled?

          result = true
          order.order_items.reload
          order.order_items.each do |order_item|
            result &= deallocate_item(order_item, status_match)
          end
        end

        def item_update(order_item, initial_count, final_count)
          return false unless inventory_tracking_enabled?

          result = true
          if order_item.is_inventory_allocated?
            initial_count = 0 if initial_count.nil?
            final_count = 0 if final_count.nil?
            difference = final_count - initial_count
            result &= do_allocate_item(order_item, difference)
          elsif order_item.is_inventory_unprocessed?
            # This condition means that the item is somehow still unprocessed, we'll process it.
            # since final qty will be used to allocate, we use that
            result &= allocate_item(order_item)
          end
          result
        end

        def allocate_item(order_item, status_match = false)
          return false unless inventory_tracking_enabled?
          return false if order_item.is_inventory_allocated? || order_item.is_inventory_sold?

          do_allocate_item(order_item, order_item.qty, OrderItem::ALLOCATED_INV_STATUS, status_match)
        end

        def deallocate_item(order_item, status_match = false)
          return false unless inventory_tracking_enabled?
          return false unless order_item.is_inventory_allocated?

          do_allocate_item(order_item, -order_item.qty, OrderItem::UNALLOCATED_INV_STATUS, status_match)
        end

        def process_sell_item(order_item, integer = 1, update_allocated = true)
          result = true
          multiplier = (integer * integer) / integer
          if (multiplier == 1 && (order_item.is_inventory_allocated? ^ update_allocated)) || (multiplier == -1 && !order_item.is_inventory_sold?)
            return false
          end
          return false unless order_item.is_not_ghost?

          result &= Groovepacker::Inventory::Products.sell(order_item.product.base_product, multiplier * order_item.qty, order_item.order.store.inventory_warehouse_id, order_item.order.reallocate_inventory?, update_allocated)
          if multiplier == 1
            order_item.update_column(:inv_status, OrderItem::SOLD_INV_STATUS)
          else
            order_item.update_column(:inv_status, OrderItem::ALLOCATED_INV_STATUS)
          end
          result
        end

        def kit_item_process(order_item, kit_item, difference)
          return false unless inventory_tracking_enabled? && order_item.is_not_ghost?

          if Order::ALLOCATE_STATUSES.include?(order_item.order.status)
            Groovepacker::Inventory::Products.allocate(kit_item.option_product, difference * order_item.qty, order_item.order.store.inventory_warehouse_id)
          elsif Order::SOLD_STATUSES.include?(order_item.order.status)
            Groovepacker::Inventory::Products.sell(kit_item.option_product, difference * order_item.qty, order_item.order.store.inventory_warehouse_id, false, false)
          end
        end

        private

        def do_allocate_item(order_item, qty, status = OrderItem::ALLOCATED_INV_STATUS, status_match = false)
          return false unless inventory_tracking_enabled? && should_process_allocation?(order_item, status_match)

          result = true
          result &= Groovepacker::Inventory::Products.allocate(order_item.product.base_product, qty, order_item.order.store.inventory_warehouse_id)
          # Set on hold here when needed
          order_item.update_column(:inv_status, status) if status != order_item.inv_status
          result
        end

        def should_process_allocation?(order_item, status_match)
          (order_item.is_not_ghost? && (Order::ALLOCATE_STATUSES.include?(order_item.order.status) || status_match))
        end
      end
    end
  end
end
