module Groovepacker
  module PickList
    class IndividualPickListBuilder < PickListBuilder
      def build(qty, product, pick_list, inventory_warehouse_id)
        single_pick_list_builder = SinglePickListBuilder.new

        product.product_kit_skuss.each do |kit_product|
          pick_list = single_pick_list_builder.build(
            qty * kit_product.qty,
            kit_product.option_product,
            pick_list,
            inventory_warehouse_id)
        end
        pick_list
      end
    end
  end
end
