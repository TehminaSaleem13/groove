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
            @csv_import_summary_exists = true
            @csv_import_summary = find_or_create_csvimportsummary
            order_map = @helper.create_order_map
            @imported_orders = {}
            @created_order_items = []
            @imported_products = []
            @base_products = []
            @import_item = @helper.initialize_import_item
            index_no = mapping["increment_id"][:position] rescue 0
            final_records = @helper.build_final_records.sort_by{|k|k[index_no].to_s}.reject{ |arr| arr.all?(&:blank?) }
            final_records_test = final_records
            final_records = remove_already_imported_rows(final_records) if params[:reimport_from_scratch] != true
            Order.where("increment_id like '%\-currupted'").destroy_all
            iterate_and_import_rows(final_records, order_map, result)
            result unless result[:status]
            OrderItem.import @created_order_items
            @created_order_items.each do |item|
              item.run_callbacks(:create) { true }
            end
            make_intangible
            return result if @import_item.status=='cancelled'
            @import_item.status = 'completed'
            @import_item.save
            Groovepacker::Orders::BulkActions.new.delay(priority: 95).update_bulk_orders_status(result, nil, Apartment::Tenant.current)
            find_or_create_csvimportsummary
            final_records_test = remove_already_imported_rows(final_records_test)
            result[:add_imported] = true if final_records.uniq.count == 1
            result
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
              next if row_already_imported(final_records, single_row, index)
              #check_or_assign_import_item
              import_item = @import_item
              @import_item = ImportItem.find(@import_item.id) rescue import_item
              if @import_item.status == 'cancelled'
                check_and_destroy_order(single_row)
                break
              end
              next if @helper.blank_or_invalid(single_row)
              product_name = single_row[mapping['product_name'][:position]] rescue nil
              product_sku = single_row[mapping['sku'][:position]] rescue nil
              next unless product_sku.blank? && product_name.blank? && params[:only_for_tracking_num].present?
              inc_id = @helper.get_row_data(single_row, 'increment_id').strip
              if index!=0 and current_inc_id.present? and current_inc_id != inc_id
                begin
                  check_order_with_item(order_items_ar, index, current_inc_id, order_map, result)
                rescue Exception => e
                  Rollbar.error(e, e.message, Apartment::Tenant.current)
                end
                order_items_ar = []
              end
              current_inc_id = inc_id
              # single_row << index
              order_items_ar << single_row
              # order_items_ar = order_items_ar.uniq
              @import_item.current_increment_id = inc_id
              update_import_item(-1, -1)
              result[:order_reimported] = false
              import_single_order(single_row, index, inc_id, order_map, result)
              if final_records.count==index+1
                begin
                  check_order_with_item(order_items_ar, index+1, current_inc_id, order_map, result)
                rescue Exception => e
                  Rollbar.error(e, e.message, Apartment::Tenant.current)
                end
                order_items_ar = []
              end
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
            #items_array.each do |row|
            begin
              result = check_single_row_order_item(order, items_array, order_items_ar, index, current_inc_id, order_map, result) if order.present?
            rescue Exception => e
              Rollbar.error(e, e.message, Apartment::Tenant.current)
              result = nil
            end
              #break if result[:order_reimported] == true
            #end
            if origional_order_id
              @order.increment_id = "#{origional_order_id}"
              @order.save
            end
            # @order.update_attribute(increment_id: "#{origional_order_id}")
            result
          end

          def check_single_row_order_item(order, items_array, order_items_ar, index, current_inc_id, order_map, result)
            record_hash = []
            new_array = []
            order_items_ar.each { |row| record_hash << @helper.get_row_data(row, 'increment_id') }
            final_record.each do |row|
              new_array << row if @helper.get_row_data(row, 'increment_id').delete(' ').include?(record_hash[0].delete(' '))
            end
            order_items_ar = new_array
            qty = items_array.flatten.reject { |c| c.is_a?(String) }
            if order.order_items.count == order_items_ar.count && qty.sum == order.order_items.map(&:qty).sum
              log = {}
            #if order.order_items.count == items_array.count
              #order_item = order.order_items.where(:sku => row[0]).first
              #order_item.update_attribute(:qty, row[1]) if order_item.qty != row[1]
            else
              log = {}
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
              qty = @helper.get_row_data(single_row, 'qty').to_s.strip.to_i
              sku = @helper.get_row_data(single_row, 'sku').strip
              #if new_sku.include? sku
                #items_array.last[1] = items_array.last[1] + qty rescue nil
              #else
                items_array << [sku, qty]
              #end
              new_sku = sku
            end
            return items_array
          end

          def import_single_order(single_row, index, inc_id, order_map, result)
            if @helper.not_imported?(@imported_orders, inc_id) || params[:only_for_tracking_num]
              @order = Order.find_or_initialize_by(increment_id: "#{inc_id}")
              order_persisted = @order.persisted? ? true : false
              @order.store_id = params[:store_id]
              @order.tracking_num = single_row[mapping['tracking_num'][:position]]
              @order_required = %w(qty sku increment_id price)
              @order.save
              import_order_data(order_map, single_row, index)
              @order.addactivity("Order Import", "#{@order.store.name} Import") unless order_persisted
              @order.update_attributes(increment_id: "#{inc_id}")
              @order.save
              @order = Order.find_by_increment_id(@order.increment_id)
              update_result(result, single_row) if result[:order_reimported] == false && !params[:only_for_tracking_num]
              import_item_failed_result(result, index) unless result[:status]
              @order.set_order_status rescue nil
            else
              @import_item.previous_imported += 1
              @import_item.save # Skipped because of duplicate order
              CsvImportLogEntry.create(index: index, csv_import_summary_id: @csv_import_summary.id)
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
               begin
                @order['order_placed_time'] = Time.parse(params[:order_placed_at])
              rescue
                result[:status] = false
                result[:messages].push('Order Placed has bad parameter - ' \
                  "#{@helper.get_row_data(single_row, 'order_placed_time')}")
              end
            else
              result[:status] = false
              result[:messages].push('Order Placed is missing.')
            end
          end

          def import_for_nonunique_order_items(single_row, index)
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
            warehouse = product.product_inventory_warehousess.first
            loc = single_row[mapping['bin_location'][:position]] rescue nil
            warehouse.update_attribute(:location_primary, loc) if warehouse.present?
            CsvImportLogEntry.create(index: index, csv_import_summary_id: @csv_import_summary.id)
            update_import_item(nil, 1)
          end

          def import_order_data(order_map, single_row, index)
            single_sku = single_row[mapping['sku'][:position]] rescue nil
            if single_sku.blank?
              existing_product = Product.find_by_name(single_row[mapping['product_name'][:position]]) rescue nil

              unless params[:only_for_tracking_num]
                if existing_product.present?
                  single_row[mapping['sku'][:position]] = existing_product.primary_sku
                else
                  single_row[mapping['sku'][:position]] = ProductSku.get_temp_sku rescue nil
                end
              end
            end
            order_map.each do |single_map|
              next unless @helper.verify_single_item(single_row, single_map)
              # if sku, create order item with product id, qty
              if @helper.import_nonunique_items?(single_map)
                import_for_nonunique_order_items(single_row, index)
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
            @import_item = @import_item.dup if ImportItem.find_by_id(@import_item.try(:id)).blank?
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

          def make_intangible
            [@base_products, @imported_products].each do |products|
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

          def find_or_create_csvimportsummary
            summary_params = {file_name: params[:file_name].strip, import_type: "Order"}
            CsvImportLogEntry.where("created_at<?", DateTime.now.beginning_of_day).delete_all
            summary = CsvImportSummary.where("created_at<?", DateTime.now.beginning_of_day).destroy_all
            summary = CsvImportSummary.where("file_name=? and import_type=? and created_at>=? and created_at<=? and file_size=?", params[:file_name].strip, "Order", DateTime.now.beginning_of_day, DateTime.now.end_of_day, params[:file_size]).last
            @csv_import_summary_exists = true
            if summary.blank?
              summary_params[:file_size] = params[:file_size]
              summary = CsvImportSummary.create(summary_params)
              @csv_import_summary_exists = false
            end
            summary
          end

          def remove_already_imported_rows(final_records)
            new_records = final_records
            final_records_size = (final_records.join("\n").bytesize.to_f/1024).round(4)
            return final_records unless @csv_import_summary_exists
            if (final_records_size == @csv_import_summary.file_size.to_f) && params[:file_name].strip==@csv_import_summary.file_name
              log_entries = @csv_import_summary.csv_import_log_entries.map(&:index).uniq rescue []
              log_entries.each do |entry|
                new_records[entry]=["already_imported"]
              end
              new_records = new_records.reject(&:empty?)
              if (new_records.count+log_entries.count) == final_records.count
                final_records = new_records
              end
              Order.csv_already_imported_warning if final_records.flatten.uniq.count == 1 rescue nil
            end
            final_records
          end

          def row_already_imported(final_records, single_row, index)
            if single_row.count==1 and single_row.last=="already_imported"
              return true
            elsif final_records[index-1]==["already_imported"]
              @import_item.previous_imported = index+1
              @import_item.save # Skipped because of duplicate order
              return false
            end
          end
        end
      end
    end
  end
end
