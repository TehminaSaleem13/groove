module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrderItemImportHelper < CsvBaseImporter
          def initiate_helper
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
            @product_helper = Groovepacker::Stores::Importers::CSV::ProductImportHelper.new(params, final_record, mapping, import_action)
            @product_helper.initiate_helper
          end

          def create_new_order_item(product, single_sku, order)
            order_item = OrderItem.new
            order_item.product = product
            order_item.order = order
            order_item.sku = single_sku.strip
            order_item.qty = 0
            order_item.price = 0.0
            order_item
          end

          def create_update_order_item(single_row, product, single_sku, order)
            order_items = OrderItem.where(
              product_id: product.id,
              order_id: order.id)
            if order_items.empty?
              order_item = create_new_order_item(product, single_sku, order)
            else
              order_item = order_items.first
            end
            @product_helper.import_image(product, single_row, true)
            initialize_or_update_order_item(single_row, order_item)
            order_item
          end

          def initialize_or_update_order_item(single_row, order_item)
            %w(qty item_sale_price).each do |item|
              next unless @helper.verify_single_item(single_row, item)
              case item
              when 'qty'
                order_item.qty =  (order_item.qty.to_i +
                                  @helper.get_row_data(single_row, 'qty').to_i).to_s
              when 'item_sale_price'
                order_item.price =
                  @helper.get_row_data(single_row, 'item_sale_price')
              end
            end
          end
        end
      end
    end
  end
end
