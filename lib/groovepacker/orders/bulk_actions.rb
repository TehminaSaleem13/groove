module Groovepacker
  module Orders
    class BulkActions

      # Changes the status of orders
      def status_update(tenant, params, bulk_actions_id, username)
        # Change db for tenant
        Apartment::Tenant.switch(tenant)
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        #orders = get_all_orders(params)
        orders = $redis.get("bulk_action_data_#{bulk_actions_id}")
        orders = Marshal.load(orders)
        #orders = []
        @result = Hash.new
        @result['messages'] = []
        @result['status'] = true
        begin
          unless orders.empty?
            # Iterate over orders and check if products are in active status or not.
            # If all products of an order are in active state then change order status.
            # Save all the failed orders in an object or array.
            bulk_action.update_attributes(:total => orders.count, :completed => 0, :status => 'in_progress')
            orders.each do |order|
              #TODO# Add code for orders cancelation
              bulk_action.current = order.increment_id
              product_not_active = false
              bulk_action.save
              # Iterate all products and check if the status is something other 
              # than active then the order status can't be changed
              change_order_status(order, params, username)
              product_not_active = check_inactive_product_exist(product_not_active, params, order)
              unless product_not_active.present?
                bulk_action.completed += 1
                bulk_action.save
              end
            end
            unless bulk_action.cancel?
              bulk_action.status = @result['status'] ? 'completed' : 'failed'
              bulk_action.messages = @result['messages']
              bulk_action.current = ''
              bulk_action.save
            end
          end
        rescue # When some internal error occured 
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.current = ''
          bulk_action.save
        end

      end

      def check_inactive_product_exist(product_not_active, params, order)
        return unless params['status'].eql?('awaiting')
        order.order_items.each do |order_item|
          unless order_item.product.status.eql?('active')
            @result['status'] &= false
            @result['messages'].push('There was a problem changing order status for '+
              order.increment_id + '. Reason: Order must have active products in it'
            )
            product_not_active = true
            break
          end
        end
        product_not_active
      end

      def change_order_status(order, params, username)
        # TODO: verify this status check
        return if permitted_to_status_change(order, params)

        non_scanning_states = { 'serviceissue' => 'Service Issue', 'onhold' => 'Action Required' }
        return if order.status.in?(non_scanning_states.keys) && params[:status].eql?('scanned')

        return if order_has_inactive_or_new_products(order, params)

        order.status = params[:status]
        order.reallocate_inventory = params[:reallocate_inventory]
        order.scanned_by_status_change = false
        update_status_and_add_activity(order, username) if params[:status] == 'scanned'
        return if order.save
        set_status_and_message(false, order.errors.full_messages)
      end

      def permitted_to_status_change(order, params)
        (Order::SOLD_STATUSES.include?(order.status) && Order::UNALLOCATE_STATUSES.include?(params[:status])) ||
          (Order::UNALLOCATE_STATUSES.include?(order.status) && Order::SOLD_STATUSES.include?(params[:status]))
      end

      def order_has_inactive_or_new_products(order, params)
        return false unless order.has_inactive_or_new_products && params[:status].in?(%w(awaiting scanned))
        # Put on hold if order status not in serviceissue
        if params[:status].eql? 'awaiting'
          order.status = 'onhold'
          order.save
        end

        #@result['notice_messages'].push 'One or more of the selected orders contains'\
        #    ' New or Inactive items so they can not be changed to Awaiting.'\
        #    ' <a target="_blank"  href="https://groovepacker.freshdesk.com/solution/articles/6000058066-how-do-order-statuses-and-product-statuses-work-in-goovepacker-">'\
        #    'More Info</a>.'
        true
      end

      def update_status_and_add_activity(order, username)
        order.scanned_on = Time.now
        order.packing_user_id = current_user
        order.scanned_by_status_change = true
        order.addactivity('Order Manually Moved To Scanned Status', username)
      end

      # Extracts all the orders from orderIds in params
      # def get_all_orders(params)
      #   if params['select_all']
      #     orders = Order.all
      #   elsif params['orderArray'].present?
      #     order_ids = params['orderArray'].map { |o| o['id'] }
      #     orders = Order.where(id: order_ids)
      #   end
      #   orders
      # end
      def delete(current_tenant, params, bulkaction_id, username)
        Apartment::Tenant.switch(current_tenant)
        bulk_action = GrooveBulkActions.find(bulkaction_id)
        orders = $redis.get("bulk_action_delete_data_#{bulkaction_id}")
        orders = Marshal.load(orders)
        result = Hash.new
        result['messages'] = []
        result['status'] = true
        bulk_action.update_attributes(:total => orders.count, :completed => 0, :status => 'in_progress')
        orders.each do |order|
          bulk_action.update_attributes(current: order.increment_id, completed: bulk_action.completed + 1)
          product_not_active = false
          result['messages'].push('There was a problem deleting order '+ order.increment_id ) unless order.destroy
        end
        unless bulk_action.cancel?
          bulk_action.status = result['status'] ? 'completed' : 'failed'
          bulk_action.messages = result['messages']
          bulk_action.current = ''
          bulk_action.save
        end
      end

      def duplicate(tenant, params, bulk_actions_id)
        Apartment::Tenant.switch(tenant)
        result = Hash.new
        result['messages'] =[]
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        orders = $redis.get("bulk_action_duplicate_data_#{bulk_actions_id}")
        orders = Marshal.load(orders)
        bulk_action.update_attributes(:total => orders.count, :completed => 0, :status => 'in_progress')
        index = 0
        temp_increment_id = ''
        orders.each do |order|
          neworder = order.dup
          begin
            temp_increment_id = order.increment_id + "(duplicate"+index.to_s+ ")"
            neworder.increment_id = temp_increment_id
            orderslist = Order.where(:increment_id => temp_increment_id)
            index = index + 1
            bulk_action.update_attributes(current: order.increment_id, completed: bulk_action.completed + 1)
          end while orderslist.present?
          neworder.save(:validate => false)
          # current_user = User.find_by_id(GroovRealtime.current_user_id)
          # unless neworder.persisted?
          #   result['status'] = false
          #   result['error_messages'] = neworder.errors.full_messages
          # else
          #   Order.add_activity_to_new_order(neworder, order.order_items, current_user)
          # end
        end

        unless bulk_action.cancel?
          bulk_action.status = result['status'] ? 'completed' : 'failed'
          bulk_action.messages = result['messages']
          bulk_action.current = ''
          bulk_action.save
        end        
      end

      def import_csv_orders(tenant, store_id, data, current_user_id)
        Apartment::Tenant.switch(tenant)
        if OrderImportSummary.where(status: 'in_progress').blank?
          OrderImportSummary.delete_all
          order_import_summary = OrderImportSummary.new
          order_import_summary.user_id = current_user_id
          order_import_summary.status = 'not_started'
          order_import_summary.save
          order_import_summaries = OrderImportSummary.where(status: 'not_started')
          if !order_import_summaries.blank?
            ordered_import_summaries = order_import_summaries.order('updated_at' + ' ' + 'desc')
            ordered_import_summaries.each do |order_import_summary|
              if order_import_summary == ordered_import_summaries.first
                ImportItem.where(store_id: store_id).delete_all
                import_item = ImportItem.find_by_store_id(store_id)
                if import_item.nil?
                  import_item = ImportItem.new
                  import_item.store_id = store_id
                end
                import_item.order_import_summary_id = order_import_summary.id
                import_item.status = 'not_started'
                import_item.save
                import_csv = ImportCsv.new
                # import_csv.delay(:run_at => 1.seconds.from_now).import Apartment::Tenant.current, data.to_s
                import_csv.import(tenant, data)
                order_import_summary.reload
                if order_import_summary.status != 'cancelled'
                  order_import_summary.status = 'completed'
                  order_import_summary.save
                end
              elsif order_import_summary.status != 'in_progress'
                order_import_summary.delete
              end
            end
          end
        end
      end

      def update_bulk_orders_status(result, params, tenant)
        Apartment::Tenant.switch(tenant)
        bulk_action = GrooveBulkActions.where("identifier='order' and activity='status_update'").last
        bulk_action_update_status(bulk_action, "in_progress")
        count = 1
        updated_products = Product.where(status_updated: true)
        orders = Order.includes(:order_items).where("order_items.product_id IN (?)", updated_products.map(&:id))
        (orders||[]).each do |order|
          order.update_order_status
          bulk_action.completed = count
          bulk_action.save
          count += 1
        end
        updated_products.update_all(status_updated: false)
        bulk_action_update_status(bulk_action, "completed")
      end

      def bulk_action_update_status(bulk_action, status)
        bulk_action.status = status
        bulk_action.save
      end
    end
  end
end
