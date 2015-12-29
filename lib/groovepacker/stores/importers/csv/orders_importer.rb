module Groovepacker
  module Stores
    module Importers
      module CSV
        # The following class imports orders and conatining items
        # for each order from a csv file.
        class OrdersImporter < CsvBaseImporter
          include ProductsHelper

          def import
            initialize_helpers
            result = build_result
            order_map = @helper.create_order_map
            @imported_orders = {}
            @import_item = @helper.initialize_import_item
            final_records = @helper.build_final_records
            iterate_and_import_rows(final_records, order_map, result)
            result unless result[:status]
            @import_item.status = 'completed'
            @import_item.save
            result
          end

          def iterate_and_import_rows(final_records, order_map, result)
            final_records.each_with_index do |single_row, index|
              @import_item.reload
              break if @import_item.status == 'cancelled'
              next if @helper.blank_or_invalid(single_row)

              @import_item.current_increment_id = inc_id = @helper.get_row_data(single_row, 'increment_id')
              update_import_item(-1, -1)

              if @helper.not_imported?(@imported_orders, inc_id)
                @order = Order.find_or_create_by_increment_id(inc_id)
                @order.store_id = params[:store_id]
                @order_required = %w(qty sku increment_id price)
                import_order_data(order_map, single_row)

                update_result(result, single_row)
                import_item_failed_result(result, index) unless result[:status]
              else
                @import_item.previous_imported += 1
                @import_item.save
                # Skipped because of duplicate order
              end
            end
          end

          def import_item_failed_result(result, index)
            @import_item.status = 'failed'
            @import_item.message = 'Import halted because of errors, ' \
              'the last imported row was ' +
              index.to_s + 'Errors: ' +
              result[:messages].join(',')
            @import_item.save
          end

          def update_result(result, single_row)
            if @order_required.length > 0
              result[:status] = false
              @order_required.each do |required_element|
                result[:messages].push("#{required_element} is missing.")
              end
            end
            return unless result[:status]
            import_order_time(single_row, result)
            result = save_order_and_update_count(result) if result[:status]
          end

          def import_order_time(single_row, result)
            if @helper.order_placed_time_mapped?(single_row)
              begin
                @order['order_placed_time'] = @helper.calculate_order_placed_time(single_row)
              rescue
                result[:status] = false
                result[:messages].push('Order Placed has bad parameter - ' \
                  "#{@helper.get_row_data(single_row, 'order_placed_time')}")
              end
            elsif !params[:order_placed_at].nil?
              require 'time'
              @order['order_placed_time'] = Time.parse(params[:order_placed_at])
            else
              result[:status] = false
              result[:messages].push('Order Placed is missing.')
            end
          end

          def import_for_nonunique_order_items(single_row)
            return if mapping['sku'].nil?
            update_import_item(1, 0)
            single_sku = @helper.get_row_data(single_row, 'sku')
            product_skus = ProductSku.where(
              sku: single_sku.strip)
            if !product_skus.empty?
              product = product_skus.first.product
              order_item = @order_item_helper.create_update_order_item(single_row, product, single_sku, @order)
              save_order_item(order_item)
              @product_helper.update_product(product, single_row)
            else # no sku is found
              product = Product.new
              set_product_info(product, single_row)
            end
            update_import_item(nil, 1)
          end

          def import_order_data(order_map, single_row)
            order_map.each do |single_map|
              next unless @helper.verify_single_item(single_row, single_map)
              # if sku, create order item with product id, qty
              if @helper.import_nonunique_items?(single_map)
                import_for_nonunique_order_items(single_row)
              elsif single_map == 'firstname'
                @helper.import_first_name(@order, single_row, single_map)
              elsif @helper.import_unique_items?(single_map)
                import_for_unique_order_items(single_row)
              else
                @order[single_map] =
                  @helper.get_row_data(single_row, single_map)
              end

              @order_required.delete(single_map) if @order_required.include? single_map
            end
          end

          def update_import_item(items = nil, imported_items = nil)
            @import_item.current_order_items = items unless items.nil?
            @import_item.current_order_imported_item = imported_items unless imported_items.nil?
            @import_item.save
          end

          def import_for_unique_order_items(single_row)
            single_inc_id = @helper.get_row_data(single_row, 'increment_id')
            @order['increment_id'] = single_inc_id
            @order_required.delete('increment_id')
            single_sku = @helper.get_row_data(single_row, 'sku')
            update_import_item(1, 0)
            @order_increment_sku = single_inc_id + '-' + single_sku.strip
            product_skus = ProductSku.where(
              ['sku like (?)', @order_increment_sku + '%'])
            if product_skus
              @product_helper.check_and_update_prod_sku(product_skus, @order_increment_sku)
              update_order_increment_sku(product_skus)
            end
            @product_helper.create_update_base_prod(single_row, single_sku)
            product = Product.new
            set_product_info(product, single_row, true)
          end

          def update_order_increment_sku(product_skus)
            @order_increment_sku =  @order_increment_sku + '-' +
                                    (product_skus.length + 1).to_s
          end

          def set_product_info(product, single_row, unique_order_item = false)
            @product_helper.import_product_data(product, single_row, @order_increment_sku, unique_order_item)
            order_item = @order_item_helper.import_new_order_item(
              single_row, product,
              @helper.get_sku(single_row, @order_increment_sku, unique_order_item))
            @order_required.delete('sku')
            save_order_item(order_item)

            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def save_order_item(order_item)
            @order_required.delete('qty')
            @order_required.delete('price')
            @order.order_items << order_item
          end

          def save_order_and_update_count(result)
            begin
              @helper.update_status_and_save(@order)
              @imported_orders[@order.increment_id] = true
              @import_item.success_imported += 1
              @import_item.save
            rescue ActiveRecord::RecordInvalid => e
              messages = @order.errors.full_messages + e.message
              result = @helper.update_count_error_result(result, messages)
            rescue ActiveRecord::StatementInvalid => e
              result = @helper.update_count_error_result(result, e.messages)
            end
            result
          end

          def initialize_helpers
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
            @order_item_helper = Groovepacker::Stores::Importers::CSV::OrderItemImportHelper.new(params, final_record, mapping, import_action)
            @product_helper = Groovepacker::Stores::Importers::CSV::ProductImportHelper.new(params, final_record, mapping, import_action)
            @order_item_helper.initiate_helper
            @product_helper.initiate_helper
          end
        end
      end
    end
  end
end
