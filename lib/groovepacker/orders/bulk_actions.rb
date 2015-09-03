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
            orders.each do |order|
              #TODO# Add code for orders cancelation
              bulk_action.current = order.increment_id
              product_not_active = false
              bulk_action.save
              # Iterate all products and check if the status is something other 
              # than active then the order status can't be changed
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
    end
  end
end