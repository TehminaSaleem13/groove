module Groovepacker
  module Orders
    class BulkActions
      include OrdersHelper

      def status_update(tenant, params, bulk_actions_id)
        # Change db for tenant
        Apartment::Tenant.switch(tenant)

        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        
        orders = list_selected_orders(params)

        unless orders.nil?
          # update the bulk action object with updating status

          # Iterate over orders and check if products are in active state or not.
          # If all products of an order are in active state then change order status.
          # Save all the failed orders in an object or array.

          # Update the BulkActionObject with current status.
        end

      end
    end
  end
end