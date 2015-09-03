module Groovepacker
  module Dashboard
    module Stats
      class Base
        attr_accessor :duration

        def initialize(duration)
          @duration = duration
        end

        def get_scanned_count(order)
          count = 0
          order.order_items.each do |order_item|
            if order_item.product.is_kit == 1
              if order_item.product.kit_parsing == 'single'
                count = count + order_item.scanned_qty
              elsif order_item.product.kit_parsing == 'individual'
                count = count + get_individual_kit_qty(order_item)
              else
                count = count + order_item.single_scanned_qty
                count = count + get_individual_kit_qty(order_item)
              end
            else
              count = count + order_item.scanned_qty
            end
          end
          count
        end

        def get_individual_kit_qty(order_item)
          count = 0
          order_item.order_item_kit_products.each do |kit_product|
            count = count + kit_product.scanned_qty
          end
          count
        end
      end
    end
  end
end