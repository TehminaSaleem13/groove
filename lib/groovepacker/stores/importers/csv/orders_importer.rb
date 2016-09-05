module Groovepacker
  module Stores
    module Importers
      module CSV
        require 'timeout'
        # The following class imports orders and conatining items
        # for each order from a csv file.
        class OrdersImporter < CsvBaseImporter
          include ProductsHelper

          def import
            initialize_helpers
            result = build_result
            order_map = @helper.create_order_map
            @imported_orders = {}
            @created_order_items = []
            @imported_products = []
            @base_products = []
            @import_item = @helper.initialize_import_item
            final_records = @helper.build_final_records     
            Order.where("increment_id like '%\-currupted'").destroy_all
            iterate_and_import_rows(final_records, order_map, result)
            result unless result[:status]
            OrderItem.import @created_order_items
            perform_after_save_callbacks
            return result if @import_item.status=='cancelled'
            @import_item.status = 'completed'
            @import_item.save
            result
          end

          def perform_after_save_callbacks
            tenant = Apartment::Tenant.current
            min_order_item_id = @created_order_items.min.id rescue nil
            max_order_item_id = @created_order_items.max.id rescue nil
            min_product_id = @imported_products.min.id rescue nil
            max_product_id = @imported_products.max.id rescue nil
            min_base_product_id = @base_products.min.id rescue nil
            max_base_product_id = @base_products.max.id rescue nil
            run_order_items = OrdersImporter.new(params, final_record, mapping, nil)
            run_order_items.delay.run_order_items_callback(min_order_item_id, max_order_item_id, tenant, min_product_id, max_product_id, min_base_product_id, max_base_product_id)
          end

          def run_order_items_callback(min_order_item_id, max_order_item_id, tenant, min_product_id, max_product_id, min_base_product_id, max_base_product_id)
            Apartment::Tenant.switch tenant
            order_items = OrderItem.where("id >= ? and id <= ?", min_order_item_id, max_order_item_id)
            order_items.each do |item|
              item.run_callbacks(:create) { true }
            end
            make_intangible(min_product_id, max_product_id, min_base_product_id, max_base_product_id)
          end

          def check_or_assign_import_item
            return unless ImportItem.where(id: @import_item.id).blank?
            import_item_id = @import_item.id
            @import_item = @import_item.dup  
            @import_item.id = import_item_id
            @import_item.save
          end

          def iterate_and_import_rows(final_records, order_map, result)
            current_inc_id = nil;
            order_items_ar = [];
            final_records.each_with_index do |single_row, index|
              #check_or_assign_import_item
              @import_item = ImportItem.find_by_id(@import_item.id) rescue @import_item
              if @import_item.status == 'cancelled'
                check_and_destroy_order(single_row)
                break
              end
              next if @helper.blank_or_invalid(single_row)
              inc_id = @helper.get_row_data(single_row, 'increment_id').strip
              if index!=0 and current_inc_id != inc_id
                check_order_with_item(order_items_ar, index, current_inc_id, order_map, result) rescue nil
                order_items_ar = []
              end
              current_inc_id = inc_id
              order_items_ar << single_row
              @import_item.current_increment_id = inc_id
              update_import_item(-1, -1)
              result[:order_reimported] = false
              import_single_order(single_row, index, inc_id, order_map, result)
            end
            GC.start
          end

          def check_and_destroy_order(single_row)
            inc_id = @helper.get_row_data(single_row, 'increment_id').strip
            Order.find_by_increment_id(inc_id).destroy rescue nil
          end

          def check_order_with_item(order_items_ar, index, current_inc_id, order_map, result)
            order = Order.includes(:order_items).find_by_increment_id("#{current_inc_id}-currupted")
            items_array = get_item_array(order_items_ar)
            items_array.each do |row|        
              result = check_single_row_order_item(order_items_ar, index, current_inc_id, order_map, result)
              break if result[:order_reimported] == true
            end
            @order.update_attribute(increment_id: "#{origional_order_id}") if origional_order_id
            result
          end

          def check_single_row_order_item(order, items_array, order_items_ar, index, current_inc_id, order_map, result)
            if order.order_items.count == items_array.count 
              order_item = order.order_items.where(:sku => row[0]).first
              order_item.update_attribute(:qty, row[1]) if order_item.qty != row[1]
            else
              order.destroy
              @created_order_items.pop(order_items_ar.count)
              new_index = (index - order_items_ar.count + 1)
              order_items_ar.each do |order_item|
                result[:order_reimported] = true
                import_single_order(order_item, new_index, current_inc_id, order_map, result)
                new_index = new_index + 1
              end
            end
            result
          end

          def get_item_array(order_items_ar)
            new_sku = []
            items_array = []
            order_items_ar.each do |single_row|
              qty = @helper.get_row_data(single_row, 'qty').strip.to_i
              sku = @helper.get_row_data(single_row, 'sku').strip
              if new_sku.include? sku 
                items_array.last[1] = items_array.last[1] + qty rescue nil
              else
                items_array << [sku, qty]
              end
              new_sku = sku 
            end
            return items_array 
          end

          def import_single_order(single_row, index, inc_id, order_map, result)
            if @helper.not_imported?(@imported_orders, inc_id)
              @order = Order.find_or_initialize_by_increment_id(inc_id)
              order_persisted = @order.persisted? ? true : false
              @order.store_id = params[:store_id]
              @order_required = %w(qty sku increment_id price)
              @order.save
              @order.addactivity("Order Import", "#{@order.store.name} Import") unless order_persisted
              @order.update_attributes(increment_id: "#{inc_id}-currupted") unless order_persisted 
              import_order_data(order_map, single_row)
              update_result(result, single_row) if result[:order_reimported] == false
              import_item_failed_result(result, index) unless result[:status]
              @order.set_order_status
            else
              @import_item.previous_imported += 1
              @import_item.save # Skipped because of duplicate order
            end
          end

          def import_item_failed_result(result, index)
            @import_item.status = 'failed'
            @import_item.message = "Import halted because of errors, the last imported row was #{index.to_s} Errors: #{result[:messages].join(',')}"
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
            params[:order_placed_at] = "#{DateTime.now()}" if params[:order_date_time_format] == 'Default'
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
              @created_order_items << order_item
              addactivity_and_delete_required(product)
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
                @order[single_map] = @helper.get_row_data(single_row, single_map)
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
            product_skus = ProductSku.where(['sku like (?)', @order_increment_sku + '%'])
            if product_skus
              @product_helper.check_and_update_prod_sku(product_skus, @order_increment_sku)
              update_order_increment_sku(product_skus)
            end
            @base_products << @product_helper.create_update_base_prod(single_row, single_sku)
            product = Product.new
            set_product_info(product, single_row, true)
          end

          def update_order_increment_sku(product_skus)
            @order_increment_sku =  "#{@order_increment_sku}-#{(product_skus.length + 1).to_s}"
          end

          def set_product_info(product, single_row, unique_order_item = false)
            @imported_products << @product_helper.import_product_data(product, single_row, @order_increment_sku, unique_order_item)
            order_item = @order_item_helper.create_new_order_item( single_row,
                                                                   product,
                                                                   @helper.get_sku(single_row, @order_increment_sku, unique_order_item),
                                                                   @order
                                                                  )
            @created_order_items << order_item
            @order_required.delete('sku')
            addactivity_and_delete_required(product)
            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def addactivity_and_delete_required(product)
            @order.addactivity("Item with SKU: #{product.primary_sku} Added", "#{@order.store.name} Import")
            @order_required.delete('qty')
            @order_required.delete('price')
            # @order.order_items << order_item
          end

          def save_order_and_update_count(result)
            begin
              @helper.update_status_and_save(@order)
              @imported_orders["#{origional_order_id}"] = true if origional_order_id
              @import_item.success_imported += 1
              @import_item.save
            rescue ActiveRecord::RecordInvalid => e
              messages = (@order.errors.full_messages << e.message) rescue @order.errors.full_messages
              result = @helper.update_count_error_result(@import_item, result, messages)
            rescue ActiveRecord::StatementInvalid => e
              result = @helper.update_count_error_result(@import_item, result, e.messages)
            end
            result
          end

          def make_intangible(min_product_id, max_product_id, min_base_product_id, max_base_product_id)
            imported_products = Product.where("id >= ? and id <= ?", min_product_id, max_product_id)
            base_products = Product.where("id >= ? and id <= ?", min_base_product_id, max_base_product_id)
            [base_products, imported_products].each do |products|
              products.each do |product|
                make_product_intangible(product) unless product.base_sku
                product.reload
                product.update_product_status
              end
            end
          end

          def initialize_helpers
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
            @order_item_helper = Groovepacker::Stores::Importers::CSV::OrderItemImportHelper.new(params, final_record, mapping, import_action)
            @product_helper = Groovepacker::Stores::Importers::CSV::ProductImportHelper.new(params, final_record, mapping, import_action)
            @order_item_helper.initiate_helper
            @product_helper.initiate_helper
          end

          def origional_order_id
            @order.increment_id.split("-currupted").first rescue nil
          end
        end
      end
    end
  end
end