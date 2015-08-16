module Groovepacker
  module PickList
    class SinglePickListBuilder < PickListBuilder
      def build(qty, product, pick_list, inventory_warehouse_id)
        product_skus = product.product_skus

        product_inventory_warehouse =
          product.get_inventory_warehouse_info(inventory_warehouse_id)
        sku_found = false
        if !product_inventory_warehouse.nil?
          primary_location = product_inventory_warehouse.location_primary
          secondary_location = product_inventory_warehouse.location_secondary
        else
          primary_location = "-"
          secondary_location = "-"
        end

        if !product_skus.first.nil?
          sku = product_skus.first.sku

          if pick_list.length > 0
            pick_list.each do |item|
              if item['sku']== sku
                sku_found = true
                item['qty'] = item['qty'] + qty
                break
              end
            end
            if !sku_found
              pick_list.push(build_pick_list_item(
                               primary_location, sku, qty,
                               product.name, secondary_location))
            end
          else
            pick_list.push(build_pick_list_item(
                             primary_location, sku, qty,
                             product.name, secondary_location))
          end
        end
        pick_list
      end
    end
  end
end
