module Groovepacker
	module Inventory
		class BulkActions

      include Groovepacker::Inventory::Helper

      def process_all(tenant, bulk_actions_id)
        Apartment::Tenant.switch(tenant)
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
          Apartment::Tenant.switch(tenant)
          if inventory_tracking_enabled?
            orders = Order.all
            check_length = check_after_every(orders.length)
            bulk_action.total = orders.length
            bulk_action.completed = 0
            bulk_action.status = 'in_progress'
            bulk_action.save
            orders.each_with_index do |single_order, index|
              do_process_single(single_order)

              if (index + 1) % check_length === 0 || index === (orders.length - 1)
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
            end
            bulk_action.status = 'completed'
            bulk_action.save
          else
            do_unprocess_all
            general_setting = GeneralSetting.all.first
            general_setting.update_column(:inventory_tracking, false)
            GeneralSetting.unset_setting
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Processing failed'] + [e.message]
          bulk_action.save
        end
        true
      end

      def unprocess_all(tenant, bulk_actions_id)
        Apartment::Tenant.switch(tenant)
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
          unless inventory_tracking_enabled?
            do_unprocess_all
          end
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
          #Log e somewhere
        end
        true
      end

      def do_process_single(order)
        #Force allocate the order (just like it would when you start)
        Groovepacker::Inventory::Orders.allocate(order, true)
        # Try to deallocate with the status check
        # Try to sell off the ones which weren't deallocated
        if Order::UNALLOCATE_STATUSES.include? order.status
          Groovepacker::Inventory::Orders.deallocate(order)
        elsif Order::SOLD_STATUSES.include? order.status
          Groovepacker::Inventory::Orders.sell(order)
        end
        true
      end

      def do_unprocess_all
        ProductInventoryWarehouses.update_all(available_inv: 0, allocated_inv: 0, sold_inv: 0)
        OrderItem.update_all(inv_status: OrderItem::DEFAULT_INV_STATUS)
        true
      end

      def check_after_every(length)
        if length <= 1000
          return 5
        end
        if length <= 5000
          return 25
        end
        if length <= 10000
          return 50
        end
        return 100
      end

		end
	end
end
