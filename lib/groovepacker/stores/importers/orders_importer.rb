# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      class OrdersImporter < Importer
        def import
          {}
        end

        def import_single(_hash)
          {}
        end

        def search_and_import_single_order(hash)
          Apartment::Tenant.switch!(hash[:tenant])
          order_no = hash[:order_no]
          user_id = hash[:user_id]
          scan_pack_setting = ScanPackSetting.last
          stores = Store.where('status=? and store_type NOT IN (?)', true, %w[CSV system])
          ss_stores = stores.where("store_type='Shipstation API 2'")
          other_stores = if scan_pack_setting.scan_by_shipping_label
                           []
                         else
                           stores.where(store_type: %w[BigCommerce
                                                       ShippingEasy Shopify Shippo])
                         end
          # o_stores = stores.where("store_type!='Shipstation API 2'")
          [ss_stores, other_stores].each { |st| run_for_each_store(st, order_no, user_id) }
          # run_for_each_store(s_stores, order_no)
        end

        private

        def run_for_each_store(stores, order_no, user_id)
          order_no = CGI.escape(order_no)
          stores.each do |store|
            break if check_order_exists(order_no)
            next unless store.on_demand_import || store.on_demand_import_v2

            import_item = ImportItem.create(store_id: store.id)
            handler = Groovepacker::Utilities::Base.new.get_handler(store.store_type, store, import_item)
            context = Groovepacker::Stores::Context.new(handler)
            if store.store_type == 'Shipstation API 2'
              context.import_single_order_from_ss_rest(order_no, user_id, true)
            else
              context.import_single_order_from(order_no, user_id)
            end
            ImportItem.where(store_id: store.id, order_import_summary_id: nil).destroy_all
            # ImportItem.where("status IS NULL").destroy_all
          end
        end

        def check_order_exists(order_no)
          order = Order.find_by_increment_id(order_no)
          order.blank? ? false : true
        end
      end
    end
  end
end
