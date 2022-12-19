# frozen_string_literal: true

module Groovepacker
  module PickList
    class PickListBuilder
      def build_pick_list_item(primary_location,
                               sku, qty, name, secondary_location)
        pick_list_item = {}
        pick_list_item['primary_location'] = primary_location
        pick_list_item['sku'] = sku
        pick_list_item['qty'] = qty
        pick_list_item['name'] = name
        pick_list_item['secondary_location'] = secondary_location
        pick_list_item
      end

      def build(_order_item, _product,
                _pick_list, _inventory_warehouse_id)
        []
      end
    end
  end
end
