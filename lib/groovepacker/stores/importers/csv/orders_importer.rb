module Groovepacker
  module Stores
    module Importers
      module CSV
        # The following class imports orders and conatining items
        # for each order from a csv file.
        class OrdersImporter < CsvBaseImporter
          include ProductsHelper

          def import
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
            result = build_result
            order_map = @helper.create_order_map
            @imported_orders = {}
            @import_item = @helper.initialize_import_item
            if params[:contains_unique_order_items] == true
              final_records = @helper.build_filtered_final_record
            else
              final_records = final_record
            end
            iterate_and_import_rows(final_records, order_map, result)

            result unless result[:status]
            @import_item.status = 'completed'
            @import_item.save
            result
          end

          def iterate_and_import_rows(final_records, order_map, result)
            final_records.each_with_index do |single_row, index|
              next if @helper.blank_row?(single_row)
              if  @helper.verify_single_item(single_row, 'increment_id') &&
                  @helper.verify_single_item(single_row, 'sku')
                @import_item.current_increment_id = inc_id = @helper.get_row_data(single_row, 'increment_id')
                update_import_item(-1, -1)

                if not_imported?(inc_id)
                  @order = Order.find_or_create_by_increment_id(inc_id)
                  @order.store_id = params[:store_id]
                  @order_required = %w(qty sku increment_id price)
                  import_order_data(order_map, single_row)

                  update_result(result, single_row)
                else
                  @import_item.previous_imported += 1
                  @import_item.save
                  # Skipped because of duplicate order
                end
              else
                next
              end
              import_item_failed_result(result, index) unless result[:status]
            end
          end

          def not_imported?(inc_id)
            @imported_orders.key?(inc_id) ||
              Order.where(
                increment_id: inc_id).empty? ||
              params[:contains_unique_order_items] == true
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
                calculate_order_placed_time(single_row)
              rescue
                result[:status] = false
                result[:messages].push('Order Placed has bad parameter - ' \
                  "#{@helper.get_row_data(single_row, 'order_placed_time')}")
              end
            elsif !params[:order_placed_at].nil?
              require 'time'
              time = Time.parse(params[:order_placed_at])
              @order['order_placed_time'] = time
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
              create_update_order_item(single_row, product, single_sku)
              @helper.update_product(product, single_row)
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
                import_first_name(single_row, single_map)
              elsif @helper.import_unique_items?(single_map)
                import_for_unique_order_items(single_row)
              else
                @order[single_map] =
                  @helper.get_row_data(single_row, single_map)
              end

              @order_required.delete(single_map) if @order_required.include? single_map
            end
          end

          def import_first_name(single_row, single_map)
            name = @helper.get_row_data(single_row, single_map)
            if  mapping['lastname'].nil? ||
                mapping['lastname'][:position] == 0
              arr = name.blank? ? [] : name.split(' ')
              @order.firstname = arr.shift
              @order.lastname = arr.join(' ')
            else
              @order.firstname = name
            end
          end

          def create_update_order_item(single_row, product, single_sku)
            order_items = OrderItem.where(
              product_id: product.id,
              order_id: @order.id)
            if order_items.empty?
              order_item = @helper.import_new_order_item(single_row, product, single_sku)
              @helper.import_image(product, single_row, true)
            else
              order_item = update_order_item(single_row, product, single_sku)
            end
            save_order_item(order_item)
          end

          def update_import_item(items = nil, imported_items = nil)
            @import_item.current_order_items = items unless items.nil?
            @import_item.current_order_imported_item = imported_items unless imported_items.nil?
            @import_item.save
          end

          def update_order_item(single_row, product, single_sku)
            order_item = OrderItem.where(
              product_id: product.id,
              order_id: @order.id,
              sku: single_sku.strip).first
            @helper.import_image(product, single_row, true)
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
            order_item
          end

          def import_for_unique_order_items(single_row)
            single_inc_id = @helper.get_row_data(single_row, 'increment_id')
            @order['increment_id'] = single_inc_id
            @order_required.delete('increment_id')
            single_sku = @helper.get_row_data(single_row, 'sku')
            update_import_item(1, 0)

            @order_increment_sku = single_inc_id + '-' + single_sku.strip
            check_and_update_prod_sku
            @helper.create_update_base_prod(single_row, single_sku)
            
            product = Product.new
            set_product_info(product, single_row, true)
          end

          def check_and_update_prod_sku
            product_skus = ProductSku.where(
              ['sku like (?)', @order_increment_sku + '%'])
            return if product_skus.empty?
            product_sku = product_skus.where(sku: @order_increment_sku).first
            if product_sku
              product_sku.sku = @order_increment_sku + '-1'
              if params[:generate_barcode_from_sku] == true
                product = product_sku.product
                product.product_barcodes.last.delete
                @helper.push_barcode(product, product_sku.sku)
              end
              product_sku.save
            end
            update_order_increment_sku(product_skus)
          end

          def update_order_increment_sku(product_skus)
            @order_increment_sku =  @order_increment_sku + '-' +
                                    (product_skus.length + 1).to_s
          end

          def import_product_barcode(product, single_row, unique_order_item = false)
            if params[:generate_barcode_from_sku] == true
              @helper.push_barcode(product, get_sku(single_row, unique_order_item))
            elsif @helper.verify_single_item(single_row, 'barcode')
              barcode = @helper.get_row_data(single_row, 'barcode')
              if ProductBarcode.where(
                barcode: barcode.strip).empty?
                @helper.push_barcode(product, barcode)
              end
            end
          end

          def import_product_sku(product, single_row, unique_order_item = false)
            sku = ProductSku.new
            # sku.sku = single_row[mapping['sku'][:position]].strip
            sku.sku = get_sku(single_row, unique_order_item)
            product.product_skus << sku
          end

          def set_product_info(product, single_row, unique_order_item = false)
            import_product_data(product, single_row, unique_order_item)
            product.reload
            product.update_product_status
            order_item = @helper.import_new_order_item(
              single_row, product,
              get_sku(single_row, unique_order_item))
            @order_required.delete('sku')
            save_order_item(order_item)

            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def import_product_data(product, single_row, unique_order_item)
            @helper.import_product_name(product, single_row)
            @helper.import_product_weight(product, single_row)
            import_product_sku(product, single_row, unique_order_item)
            import_product_barcode(product, single_row, unique_order_item)
            product.store_product_id = 0
            product.store_id = params[:store_id]
            product.spl_instructions_4_packer =
              @helper.import_product_instructions(single_row)
            @helper.import_image(product, single_row)
            @helper.import_product_category(product, single_row)
            if unique_order_item
              product.base_sku = @helper.get_row_data(single_row, 'sku').strip
              product.save
            else
              @helper.import_sec_ter_sku(product, single_row)
              @helper.import_sec_ter_barcode(product, single_row)
              make_product_intangible(product) if product.save!
            end
          end

          def save_order_item(order_item)
            @order_required.delete('qty')
            @order_required.delete('price')
            @order.order_items << order_item
          end

          def get_sku(single_row, unique_order_item)
            unique_order_item ? @order_increment_sku : @helper.get_row_data(single_row, 'sku').strip
          end

          def calculate_order_placed_time(single_row)
            require 'time'
            imported_order_time =
              @helper.get_row_data(single_row, 'order_placed_time')
            separator = (imported_order_time.include? '/') ? '/' : '-'
            order_time_hash = @helper.build_order_time_hash(separator)
            @order['order_placed_time'] = DateTime.strptime(
              imported_order_time,
              order_time_hash[params[:order_date_time_format]][params[:day_month_sequence]])
          end

          def update_count_error_result(result, messages)
            result[:status] = false
            result[:messages] = messages
            @import_item.status = 'failed'
            @import_item.message = messages
            @import_item.save
            result
          end

          def update_status_and_save
            @order.status = 'onhold'
            @order.save!
            @order.addactivity(
              'Order Import CSV Import',
              Store.find(params[:store_id]).name + ' Import')
            @order.update_order_status
          end

          def save_order_and_update_count(result)
            begin
              update_status_and_save
              @imported_orders[@order.increment_id] = true
              @import_item.success_imported += 1
              @import_item.save
            rescue ActiveRecord::RecordInvalid => e
              messages = @order.errors.full_messages + e.message
              result = update_count_error_result(result, messages)
            rescue ActiveRecord::StatementInvalid => e
              result = update_count_error_result(result, e.messages)
            end
            result
          end
        end
      end
    end
  end
end
