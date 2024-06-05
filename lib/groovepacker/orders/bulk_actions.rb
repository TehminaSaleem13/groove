# frozen_string_literal: true

module Groovepacker
  module Orders
    class BulkActions
      include Groovepacker::Inventory::Helper
      include Groovepacker::Orders::ResponseMessage

      def init_results
        @result = {}
        @result['messages'] = []
        @result['status'] = true
        @scanpack_settings = ScanPackSetting.last
        @remove_skipped = @scanpack_settings.remove_skipped
      end

      # Changes the status of orders
      def status_update(tenant, params, bulk_actions_id, username)
        Apartment::Tenant.switch!(tenant)
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        orders = $redis.get("bulk_action_data_#{tenant}_#{bulk_actions_id}")
        orders = Marshal.load(orders)
        init_results
        begin
          unless orders.empty?
            bulk_action.update_attributes(total: orders.count, completed: 0, status: 'in_progress')
            orders.each do |order|
              return if check_bulk_cancel(bulk_action)

              bulk_action.update_attribute(:current, order.increment_id)
              product_not_active = false
              change_order_status(order, params, username)
              delete_boxes(order)
              product_not_active = check_inactive_product_exist(product_not_active, params, order)
              bulk_action.update_attribute(:completed, bulk_action.completed + 1) unless product_not_active.present?
            end
            check_bulk_action_completed_or_not(bulk_action)
          end
        rescue StandardError => e
          bulk_action.update_attributes(status: 'failed', messages: ['Some error occurred'], current: '')
        end
        $redis.del("bulk_action_data_#{tenant}_#{bulk_actions_id}")
      end

      def check_inactive_product_exist(product_not_active, params, order)
        return unless params['status'].eql?('awaiting')

        if order.order_items.present? && (order.order_items.map(&:qty).sum == 0 && order.order_items.map(&:skipped_qty).sum == 0)
          order.update_attribute(:status, 'onhold')
          @result['status'] &= false
          @result['messages'].push('Only orders containing Active items can be Awaiting')
          # product_not_active = true
        end
        order.order_items.each do |order_item|
          next unless order_item.product
          next if order_item.product.status.eql?('active')

          @result['status'] &= false
          @result['messages'].push('There was a problem changing order status for ' +
            order.increment_id + '. Reason: Order must have active products in it')
          product_not_active = true
          break
        end
        product_not_active
      end

      def change_order_status(order, params, username)
        pull_inv = params['pull_inv'] == true ? true : false
        return if permitted_to_status_change(order, params)

        non_scanning_states = { 'serviceissue' => 'Service Issue', 'onhold' => 'Action Required' }
        return if order.status.in?(non_scanning_states.keys) && params[:status].eql?('scanned')
        return if order_has_inactive_or_new_products(order, params)
        order.pull_inv = pull_inv
        order_status = order.status
        order.status = params[:status]
        order.scanned_on = nil if params[:status] != 'scanned'
        order.reallocate_inventory = params[:reallocate_inventory]
        order.scanned_by_status_change = false
        order.post_scanning_flag = nil
        if params[:status] == 'scanned'
          update_status_and_add_activity(order, username)
          order.order_items.each do |order_item|
            order_item.scanned_status = 'scanned'
            order_item.save
          end
          Tote.find_by_order_id(order.id).update_attributes(order_id: nil, pending_order: false) if order.tote
        else
          order.save
          retain_items = !@remove_skipped && order_status == 'scanned' && params[:status] == 'awaiting'
          if retain_items
            order.order_items.where('skipped_qty != 0').each do |order_item|
              order_item.update_attributes(qty: order_item.qty + order_item.skipped_qty, skipped_qty: 0)
            end
            order.order_items.where('removed_qty != 0').update_all(removed_qty: 0)
          end
          on_ex = params['on_ex'] ? params['on_ex'] : nil
          order.addactivity("Order Manually Moved To #{order.status.capitalize} Status", username, on_ex)
        end
        order.packing_user_id = User.find_by_username(username).try(:id)
        return if order.save

        set_status_and_message(false, order.errors.full_messages)
      end

      def permitted_to_status_change(order, params)
        (Order::SOLD_STATUSES.include?(order.status) && Order::UNALLOCATE_STATUSES.include?(params[:status])) || (Order::UNALLOCATE_STATUSES.include?(order.status) && Order::SOLD_STATUSES.include?(params[:status]))
      end

      def order_has_inactive_or_new_products(order, params)
        return false unless order.has_inactive_or_new_products && params[:status].in?(%w[awaiting scanned])

        if params[:status].eql? 'awaiting'
          order.status = 'onhold'
          order.save
        end

        # @result['notice_messages'].push 'One or more of the selected orders contains'\
        #    ' New or Inactive items so they can not be changed to Awaiting.'\
        #    ' <a target="_blank"  href="https://groovepacker.freshdesk.com/solution/articles/6000058066-how-do-order-statuses-and-product-statuses-work-in-goovepacker-">'\
        #    'More Info</a>.'
        true
      end

      def update_status_and_add_activity(order, username)
        order.scanned_on = Time.current
        current_user = begin
                         User.find_by_name('myplan')
                       rescue StandardError
                         nil
                       end
        order.packing_user_id = current_user
        order.scanned_by_status_change = true
        order.addactivity('Order Manually Moved To Scanned Status', username)
      end

      # def get_all_orders(params)
      #   if params['select_all']
      #     orders = Order.all
      #   elsif params['orderArray'].present?
      #     order_ids = params['orderArray'].map { |o| o['id'] }
      #     orders = Order.where(id: order_ids)
      #   end
      #   orders
      # end

      def clear_assigned_tote(current_tenant, bulkaction_id, user_id)
        Apartment::Tenant.switch!(current_tenant)
        bulk_action = GrooveBulkActions.find(bulkaction_id)
        orders = $redis.get("bulk_action_clear_assigned_tote_data_#{current_tenant}_#{bulkaction_id}")
        orders = Marshal.load(orders)
        order_ids = orders.pluck(:id)
        init_results
        bulk_action.update_attributes(total: orders.count, completed: 0, status: 'in_progress')
        orders.each { |order| order.reset_assigned_tote(user_id) }
        bulk_action.update_attributes(completed: orders.count)
        check_bulk_action_completed_or_not(bulk_action)
        $redis.del("bulk_action_clear_assigned_tote_data_#{current_tenant}_#{bulkaction_id}")
      end

      def delete(current_tenant, bulkaction_id, params)
        Apartment::Tenant.switch!(current_tenant)
        bulk_action = GrooveBulkActions.find(bulkaction_id)
        orders = $redis.get("bulk_action_delete_data_#{current_tenant}_#{bulkaction_id}")
        orders = Marshal.load(orders)
        order_increment_ids = orders.pluck(:increment_id)
        add_delete_log(current_tenant, order_increment_ids, 'List of Deleted Orders (25)', params, order_increment_ids.count)
        order_ids = orders.pluck(:id)
        init_results
        bulk_action.update_attributes(total: orders.count, completed: 0, status: 'in_progress')
        # orders.each do |order|
        #   return if check_bulk_cancel(bulk_action)
        #   bulk_action.update_attributes(current: order.increment_id, completed: bulk_action.completed + 1)
        #   unless order.destroy
        #     @result['status'] = false
        #     @result['messages'].push('There was a problem deleting order '+ order.increment_id )
        #   end
        # end

        Tote.where(order_id: order_ids).update_all(order_id: nil, pending_order: false)

        destroy_order_items(order_ids, bulk_action)
        Order.where(['id IN (?)', order_ids]).delete_all
        destroy_orders_associations(order_ids)
        bulk_action.update_attributes(completed: orders.count)

        check_bulk_action_completed_or_not(bulk_action)
        $redis.del("bulk_action_delete_data_#{current_tenant}_#{bulkaction_id}")
      end

      def duplicate(tenant, bulk_actions_id, username)
        Apartment::Tenant.switch!(tenant)
        init_results
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        orders = $redis.get("bulk_action_duplicate_data_#{tenant}_#{bulk_actions_id}")
        orders = Marshal.load(orders)
        bulk_action.update_attributes(total: orders.count, completed: 0, status: 'in_progress')
        temp_increment_id = ''
        orders.each do |order|
          index = 1
          return if check_bulk_cancel(bulk_action)

          neworder = order.dup
          begin
            temp_increment_id = order.increment_id.split(/[(]Duplicate|&|\+/).first + '(Duplicate-' + index.to_s + ')'
            neworder.increment_id = temp_increment_id
            orderslist = Order.where(increment_id: temp_increment_id)
            index += 1
            bulk_action.update_attributes(current: order.increment_id, completed: bulk_action.completed + 1)
          end while orderslist.present?
          if neworder.try(:store).try(:store_type) == 'ShippingEasy'
            neworder.cloned_from_shipment_id = ''
            neworder.shipment_id = ''
            neworder.prime_order_id = ''
            neworder.source_order_ids = ''
            neworder.split_from_order_id = ''
            neworder.store_order_id = ''
          end
          neworder.save(validate: false)
          neworder.persisted? ? Order.add_activity_to_new_order(neworder, order.order_items, username) : @result['status'] = false
        end
        check_bulk_action_completed_or_not(bulk_action)
        $redis.del("bulk_action_duplicate_data_#{tenant}_#{bulk_actions_id}")
      end

      def check_bulk_cancel(bulk_action)
        bulk_action.reload
        if bulk_action.cancel?
          bulk_action.update_attribute(:status, 'cancelled')
          return true
        end
        false
      end

      def check_bulk_action_completed_or_not(bulk_action)
        unless bulk_action.cancel?
          bulk_action.status = @result['status'] ? 'completed' : 'failed'
          bulk_action.update_attributes(messages: @result['messages'], current: '')
        end
      end

      def import_csv_orders(tenant, store_id, data, current_user_id)
        Apartment::Tenant.switch!(tenant)
        if OrderImportSummary.where(status: 'in_progress').blank?
          OrderImportSummary.delete_all
          order_import_summary = OrderImportSummary.create(user_id: current_user_id, status: 'not_started')
          order_import_summaries = OrderImportSummary.where(status: 'not_started')
          unless order_import_summaries.blank?
            ordered_import_summaries = order_import_summaries.order('updated_at' + ' ' + 'desc')
            ordered_import_summaries.each do |orderimport_summary|
              if orderimport_summary == ordered_import_summaries.first
                ImportItem.where(store_id: store_id).delete_all
                import_item = ImportItem.find_by_store_id(store_id)
                import_item = ImportItem.new(store_id: store_id) if import_item.nil?
                import_item.updated_orders_import = 0
                import_item.order_import_summary_id = orderimport_summary.id
                import_item.status = 'not_started'
                import_item.save
                import_csv = ImportCsv.new
                import_csv.import(tenant, data)
                orderimport_summary.reload
                orderimport_summary.update_attribute(:status, 'completed') if orderimport_summary.status != 'cancelled'
              elsif orderimport_summary.status != 'in_progress'
                orderimport_summary.delete
              end
            end
          end
        end
      end

      def update_bulk_orders_status(_result, _params, tenant)
        Apartment::Tenant.switch!(tenant)
        bulk_action = GrooveBulkActions.where("identifier='order' and activity='status_update'").last
        return if bulk_action.blank?

        bulk_action_update_status(bulk_action, 'in_progress')
        count = 1
        updated_products = Product.where(status_updated: true)
        orders = Order.eager_load(:order_items).where('order_items.product_id IN (?)', updated_products.map(&:id))
        (orders || []).find_each(batch_size: 100) do |order|
          order.update_order_status
          bulk_action.completed = count
          bulk_action.save
          count += 1
        end
        updated_products.update_all(status_updated: false)
        bulk_action_update_status(bulk_action, 'completed')
        begin
          update_all_pending_order_bulk_actions
        rescue StandardError
          nil
        end
      end

      def bulk_action_update_status(bulk_action, status)
        bulk_action.status = status
        bulk_action.save
      end

      def update_all_pending_order_bulk_actions
        bulk_actions = GrooveBulkActions.where("identifier='order' and activity='status_update' and (status!='cancelled' or status='completed' and total!=completed)")
        bulk_actions.update_all(["status='completed', completed=total"])
      end

      private

      def destroy_orders_associations(order_ids)
        OrderActivity.where(['order_id IN (?)', order_ids]).delete_all
        OrderException.where(['order_id IN (?)', order_ids]).delete_all
        OrderSerial.where(['order_id IN (?)', order_ids]).delete_all
        ShippingLabel.where(['order_id IN (?)', order_ids]).delete_all
        OrderShipping.where(['order_id IN (?)', order_ids]).delete_all
        ShipstationLabelData.where(['order_id IN (?)', order_ids]).delete_all
        Tote.where(order_id: order_ids).update_all(order_id: nil)
      end

      def destroy_order_items(order_ids, bulk_action)
        order_items = OrderItem.where(['order_id IN (?)', order_ids])

        if inventory_tracking_enabled?
          prev_attrs = bulk_action.slice('total', 'completed', 'identifier', 'activity', 'current', 'messages', 'status')

          bulk_action.update_attributes(total: order_items.count, identifier: 'inventory_balance', activity: 'adjustment')

          order_items
            .find_in_batches(batch_size: 20) do |items|
            items_ids = items.map(&:id)

            # Update inventory
            items.map(&:delete_inventory)

            bulk_action.update_attributes(completed: bulk_action.completed + items.count)

            delete_order_items(items_ids)
          end

          bulk_action.update_attributes(prev_attrs)
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

      def delete_boxes(order)
        Box.where(order_id: order.id).destroy_all
      end

      def add_delete_log(tenant, order_increment_ids, name, params, orders_count)
        Ahoy::Event.version_2.create({
          name: name,
          properties: {
            title: name,
            tenant: tenant,
            username: User.find_by_id(params[:user_id])&.username,
            objects_involved: order_increment_ids.first(25),
            objects_involved_count: orders_count
          },
          time: Time.current
        }) rescue nil
      end
    end
  end
end
