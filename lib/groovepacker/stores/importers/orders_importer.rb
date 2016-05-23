module Groovepacker
  module Stores
    module Importers
      class OrdersImporter < Importer
        def import
          {}
        end

        def import_single(hash)
          {}
        end

        def search_and_import_single_order(hash)
          Apartment::Tenant.switch(hash[:tenant])
          order_no = hash[:order_no]
          stores = Store.where("status=? and store_type NOT IN (?)", true, ['CSV', 'system'])
          s_stores = stores.where("store_type='Shipstation API 2'")
          o_stores = stores.where("store_type='BigCommerce'")
          #o_stores = stores.where("store_type!='Shipstation API 2'")
          [s_stores, o_stores].each { |st| run_for_each_store(st, order_no) }
          #run_for_each_store(s_stores, order_no)
        end

        private
          def run_for_each_store(stores, order_no)
            stores.each do |store|
              break if check_order_exists(order_no)
              next unless store.on_demand_import
              context = Groovepacker::Orders::Base.new.send(:get_context, store)
              context.import_single_order_from(order_no)
            end
          end

          def check_order_exists(order_no)
            order = Order.find_by_increment_id(order_no)
            return order.blank? ? false : true
          end

      end
    end
  end
end
