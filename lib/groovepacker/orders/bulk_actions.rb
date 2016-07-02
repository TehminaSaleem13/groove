module Groovepacker
  module Orders
    class BulkActions

      # Changes the status of orders
      def status_update(tenant, params, bulk_actions_id)
        # Change db for tenant
        Apartment::Tenant.switch(tenant)
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        orders = get_all_products(params)
        result = Hash.new
        result['messages'] = []
        result['status'] = true
        begin
          unless orders.empty?
            # Iterate over orders and check if products are in active status or not.
            # If all products of an order are in active state then change order status.
            # Save all the failed orders in an object or array.
            bulk_action.update_attributes(:total => orders.length, :completed => 0, :status => 'in_progress')
            orders.each do |order|
              #TODO# Add code for orders cancelation
              bulk_action.current = order.increment_id
              product_not_active = false
              bulk_action.save
              # Iterate all products and check if the status is something other 
              # than active then the order status can't be changed
              if params['status'].eql?('awaiting')
                order.order_items.each do |order_item|
                  unless order_item.product.status.eql?('active')
                    result['status'] &= false
                    result['messages'].push('There was a problem changing order status for '+
                      order.increment_id + '. Reason: Order must have active products in it'
                    )
                    product_not_active = true
                    break
                  end
                end
              end
              # If no products have status other than active then change the
              # status to requested status
              unless product_not_active.present?
                order.status = params['status']
                order.save
                bulk_action.completed += 1
                bulk_action.save
              end
            end
            unless bulk_action.cancel?
              bulk_action.status = result['status'] ? 'completed' : 'failed'
              bulk_action.messages = result['messages']
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

      # Extracts all the orders from orderIds in params
      def get_all_products(params)
        unless params['orderArray'].empty?  
          order_ids = params['orderArray'].map { |o| o['id'] }
          orders = Order.where(id: order_ids)
        end
        orders
      end

      def import_csv_orders(tenant, store_id, data, current_user_id)
        Apartment::Tenant.switch(tenant)
        if OrderImportSummary.where(status: 'in_progress').empty?
          OrderImportSummary.delete_all
          order_import_summary = OrderImportSummary.new
          order_import_summary.user_id = current_user_id
          order_import_summary.status = 'not_started'
          order_import_summary.save
          order_import_summaries = OrderImportSummary.where(status: 'not_started')
          if !order_import_summaries.empty?
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
