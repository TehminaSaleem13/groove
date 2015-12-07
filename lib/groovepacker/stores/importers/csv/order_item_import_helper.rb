module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrderItemImportHelper < CsvBaseImporter
          def initiate_helper
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
          end

          def import_new_order_item(single_row, product, single_sku)
            order_item = OrderItem.new
            order_item.product = product
            order_item.sku = single_sku.strip
            %w(qty item_sale_price).each do |item|
              order_item_value(item, order_item, single_row)
            end
            order_item
          end

          def order_item_value(item, order_item, single_row)
            if @helper.verify_single_item(single_row, item)
              case item
              when 'qty'
                order_item.qty = @helper.get_row_data(single_row, item)
              when 'item_sale_price'
                order_item.price = @helper.get_row_data(single_row, item)
              end
            else
              case item
              when 'qty'
                order_item.qty = 0
              when 'item_sale_price'
                order_item.price = 0.0
              end
            end
          end
        end
      end
    end
  end
end
