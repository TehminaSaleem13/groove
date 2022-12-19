# frozen_string_literal: true

module  OrderService
  class RemoveDuplicates
    def get_duplicates_order_info(params)
      tenants_list = params[:select_all] ? Tenant.all : Tenant.where(name: params[:tenant_names])
      tenants_list.find_each do |tenant|
        Apartment::Tenant.switch!(tenant.name)

        dup_order_ids = []

        Order.where('created_at > ?', 5.day.ago).group_by(&:increment_id).each do |_key, orders|
          next if orders.count == 1

          scanned_true = ((orders.map(&:status).include? 'scanned') || (orders.map(&:status).include? 'cancelled'))
          if scanned_true
            orders.each do |dup_order|
              dup_order_ids << dup_order.id unless dup_order.status == 'scanned' || dup_order.status == 'cancelled'
            end
          else
            orders.drop(1).each do |dup_order|
              dup_order_ids << dup_order.id
            end
          end
        end
        remove_orders(dup_order_ids)
      end
    end

    def remove_orders(dup_order_ids)
      destroy_orders_associations(dup_order_ids)
      Order.where(['id IN (?)', dup_order_ids]).delete_all
    end

    def destroy_orders_associations(order_ids)
      OrderActivity.where(['order_id IN (?)', order_ids]).delete_all
      OrderException.where(['order_id IN (?)', order_ids]).delete_all
      OrderSerial.where(['order_id IN (?)', order_ids]).delete_all
      OrderShipping.where(['order_id IN (?)', order_ids]).delete_all
      Tote.where(order_id: order_ids).update_all(order_id: nil)
      destroy_order_items(order_ids)
    end

    def destroy_order_items(order_ids)
      order_items = OrderItem.where(['order_id IN (?)', order_ids])

      if inventory_tracking_enabled?
        order_items
          .find_in_batches(batch_size: 1000) do |items|
          items_ids = items.map(&:id)

          # Update inventory
          items.map(&:delete_inventory)
          delete_order_items(items_ids)
        end
      else
        delete_order_items(order_items.pluck(:id))
      end
    end

    def delete_order_items(order_items_ids)
      OrderItemKitProduct.where(['order_item_id IN (?)', order_items_ids]).delete_all
      OrderItemOrderSerialProductLot.where(['order_item_id IN (?)', order_items_ids]).delete_all
      OrderItemScanTime.where(['order_item_id IN (?)', order_items_ids]).delete_all

      OrderItem.where(['id IN (?)', order_items_ids]).delete_all
    end

    def inventory_tracking_enabled?
      # Threads leak :( And this needs tenant wise setting in the same process,
      # We'll have to come up with a better solution later
      #
      # if Thread.current[:inventory_tracking_enabled].nil?
      # Thread.current[:inventory_tracking_enabled] = false
      # general_setting = GeneralSetting.all.first
      # unless general_setting.nil?
      # Thread.current[:inventory_tracking_enabled] = general_setting.inventory_tracking?
      # end
      # end
      # Thread.current[:inventory_tracking_enabled]
      # inventory_tracking_enabled = Thread.current[:inventory_tracking_enabled]
      # return inventory_tracking_enabled unless inventory_tracking_enabled.nil?
      # Thread.current[:inventory_tracking_enabled] = GeneralSetting.setting.try(:inventory_tracking?) || false
      result = false
      general_setting = GeneralSetting.setting
      result = general_setting.inventory_tracking? unless general_setting.nil?
      result
    end
  end
end
