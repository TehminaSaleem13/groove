module Groovepacker
  module Products
    class BulkActions
      include OrdersHelper

      def status_update(tenant, params, bulk_action_id)
        # Change db for tenant
        Apartment::Tenant.switch(tenant)
        
        list_selected_orders(params)
        # List selected orders


      end
    end
  end
end