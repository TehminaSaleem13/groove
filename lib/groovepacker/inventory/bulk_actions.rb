# frozen_string_literal: true

module Groovepacker
  module Inventory
    class BulkActions
      include Groovepacker::Inventory::Helper

      def process_unprocessed(order_id = nil)
        return true unless inventory_tracking_enabled?

        order = Order.where(id: order_id).first if order_id
        if order.try(:present?)
          order_items = order.order_items.includes(:order).where(inv_status: OrderItem::DEFAULT_INV_STATUS, scanned_status: 'notscanned')
        else
          order_items = OrderItem.includes(:order).where(inv_status: OrderItem::DEFAULT_INV_STATUS, scanned_status: 'notscanned')
        end
        order_items.each do |single_order_item|
          process(single_order_item)
          # if single_order_item.is_not_ghost?
          #   if Order::ALLOCATE_STATUSES.include?(single_order_item.order.status)
          #     Groovepacker::Inventory::Orders.allocate_item(single_order_item)
          #   elsif Order::SOLD_STATUSES.include?(single_order_item.order.status)
          #     Groovepacker::Inventory::Orders.process_sell_item(single_order_item, 1, false)
          #   elsif Order::UNALLOCATE_STATUSES.include?(single_order_item.order.status)
          #     single_order_item.update_column(:inv_status, OrderItem::UNALLOCATED_INV_STATUS)
          #   end
          # end
        end
      end

      def process(item)
        if item.is_not_ghost?
          if Order::ALLOCATE_STATUSES.include?(item.order.status)
            Groovepacker::Inventory::Orders.allocate_item(item)
          elsif Order::SOLD_STATUSES.include?(item.order.status)
            Groovepacker::Inventory::Orders.process_sell_item(item, 1, false)
          elsif Order::UNALLOCATE_STATUSES.include?(item.order.status)
            item.update_column(:inv_status, OrderItem::UNALLOCATED_INV_STATUS)
          end
        end
      end

      def process_all(tenant, bulk_actions_id)
        Apartment::Tenant.switch!(tenant)
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        if bulk_action.cancel?
          bulk_action.status = 'cancelled'
          bulk_action.save
          do_unprocess_all
          general_setting = GeneralSetting.all.first
          general_setting.update_column(:inventory_tracking, false)
          GeneralSetting.unset_setting
          return true
        end
        begin
          Apartment::Tenant.switch!(tenant)
          if inventory_tracking_enabled?
            orders = Order.where("status != 'scanned'")
            check_length = check_after_every(orders.length)
            bulk_action.total = orders.length
            bulk_action.completed = 0
            bulk_action.status = 'in_progress'
            bulk_action.save
            orders.each_with_index do |single_order, index|
              do_process_single(single_order)
              next unless (index + 1) % check_length === 0 || index === (orders.length - 1)

              bulk_action.reload
              if bulk_action.cancel?
                bulk_action.status = 'cancelled'
                bulk_action.save
                do_unprocess_all
                general_setting = GeneralSetting.all.first
                general_setting.update_column(:inventory_tracking, false)
                GeneralSetting.unset_setting
                return true
              end
              bulk_action.completed = index + 1
              bulk_action.save
            end
            process_unprocessed
            bulk_action.status = 'completed'
            bulk_action.save
          else
            do_unprocess_all
            general_setting = GeneralSetting.all.first
            general_setting.update_column(:inventory_tracking, false)
            GeneralSetting.unset_setting
            bulk_action.status = 'completed'
            bulk_action.save
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Processing failed'] + [e.message]
          bulk_action.save
        end
        true
      end

      def unprocess_all(tenant, bulk_actions_id)
        Apartment::Tenant.switch!(tenant)
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        if bulk_action.cancel?
          bulk_action.status = 'cancelled'
          bulk_action.save
          general_setting = GeneralSetting.all.first
          general_setting.update_column(:inventory_tracking, true)
          GeneralSetting.unset_setting
          return true
        end
        begin
          bulk_action.total = 1
          bulk_action.completed = 0
          bulk_action.status = 'in_progress'
          bulk_action.save
          do_unprocess_all unless inventory_tracking_enabled?
          bulk_action.total = 1
          bulk_action.completed = 1
          bulk_action.status = 'completed'
          bulk_action.save
        rescue Exception => e
          bulk_action.total = 1
          bulk_action.completed = 0
          bulk_action.status = 'failed'
          bulk_action.messages = ['Processing failed'] + [e.message]
          bulk_action.save
          # Log e somewhere
        end
        true
      end

      def do_process_single(order)
        if Order::ALLOCATE_STATUSES.include? order.status
          Groovepacker::Inventory::Orders.allocate(order)
        elsif Order::SOLD_STATUSES.include? order.status
          Groovepacker::Inventory::Orders.sell(order, false)
        end
        true
      end

      def do_unprocess_all
        ProductInventoryWarehouses.update_all(available_inv: 0, allocated_inv: 0, sold_inv: 0)
        OrderItem.update_all(inv_status: OrderItem::DEFAULT_INV_STATUS)
        Groovepacker::LogglyLogger.log(Apartment::Tenant.current, 'Check unprocess log',{ message: 'Check unprocess log'})
        true
      end

      def check_after_every(length)
        return 5 if length <= 1000
        return 25 if length <= 5000
        return 50 if length <= 10_000

        100
      end
    end
  end
end
