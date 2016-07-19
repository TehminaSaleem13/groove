module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrderImportHelper < CsvBaseImporter
          def blank_row?(single_row)
            single_row.each do |single_column|
              return false unless single_column.nil?
            end
            true
          end

          def get_row_data(single_row, prop)
            single_row[mapping[prop][:position]]
          end

          def verify_single_item(single_row, item)
            !mapping[item].nil? &&
              mapping[item][:position] >= 0 &&
              !single_row[mapping[item][:position]].nil?
          end

          def blank_or_invalid(single_row)
            blank_row?(single_row) ||
              !verify_single_item(single_row, 'increment_id') ||
              !verify_single_item(single_row, 'sku')
          end

          def build_final_records
            if params[:contains_unique_order_items] == true
              build_filtered_final_record
            else
              final_record
            end
          end

          def build_filtered_final_record
            existing_order_numbers = []
            filtered_final_record = []
            existing_orders = Order.all
            existing_orders.each do |order|
              existing_order_numbers << order.increment_id
            end
            final_record.each do |single_row|
              next unless verify_single_item(single_row, 'increment_id')
              filtered_final_record << single_row unless
                existing_order_numbers.include? get_row_data(single_row, 'increment_id')
            end
            filtered_final_record
          end

          def not_imported?(imported_orders, inc_id)
            imported_orders.key?(inc_id) ||
              Order.where(
                increment_id: inc_id).empty? ||
              params[:contains_unique_order_items] == true
          end

          def import_nonunique_items?(single_map)
            single_map == 'sku' &&
              !params[:contains_unique_order_items] == true
          end

          def import_unique_items?(single_map)
            single_map == 'increment_id' &&
              params[:contains_unique_order_items] == true &&
              !mapping['increment_id'].nil? &&
              !mapping['sku'].nil?
          end

          def create_order_map
            %w( address_1 address_2 city country customer_comments
                notes_internal notes_toPacker email firstname increment_id
                lastname method postcode sku state price tracking_num qty
                custom_field_one custom_field_two)
          end

          def initialize_import_item
            import_item = ImportItem.find_by_store_id(params[:store_id])
            if import_item.nil?
              import_item = ImportItem.new
              import_item.store_id = params[:store_id]
            end
            import_item.status = 'in_progress'
            import_item.current_increment_id = ''
            import_item.success_imported = 0
            import_item.previous_imported = 0
            import_item.current_order_items = -1
            import_item.current_order_imported_item = -1
            import_item.to_import = final_record.length
            import_item.save
            import_item
          end

          def order_placed_time_mapped?(single_row)
            verify_single_item(single_row, 'order_placed_time') &&
              !params[:order_date_time_format].nil? && params[:order_date_time_format] != 'Default'
          end

          def calculate_order_placed_time(single_row)
            require 'time'
            imported_order_time = "#{Time.parse(get_row_data(single_row, 'order_placed_time'))}" 
            separator = (imported_order_time.include? '/') ? '/' : '-'
            order_time_hash = build_order_time_hash(separator)           
            return DateTime.strptime(
              imported_order_time,
              order_time_hash[params[:order_date_time_format]][params[:day_month_sequence]])
          end

          def get_sku(single_row, order_increment_sku, unique_order_item)
            unique_order_item ? order_increment_sku : get_row_data(single_row, 'sku').strip
          end

          def build_order_time_hash(separator)
            {
              'YYYY/MM/DD TIME' => {
                'DD/MM' => "%Y#{separator}%d#{separator}%m %H:%M",
                'MM/DD' => "%Y#{separator}%m#{separator}%d %H:%M"
              },
              'MM/DD/YYYY TIME' => {
                'DD/MM' => "%d#{separator}%m#{separator}%Y %H:%M",
                'MM/DD' => "%m#{separator}%d#{separator}%Y %H:%M"
              },
              'YY/MM/DD TIME' => {
                'DD/MM' => "%y#{separator}%d#{separator}%m %H:%M",
                'MM/DD' => "%y#{separator}%m#{separator}%d %H:%M"
              },
              'MM/DD/YY TIME' => {
                'DD/MM' => "%d#{separator}%m#{separator}%y %H:%M",
                'MM/DD' => "%m#{separator}%d#{separator}%y %H:%M"
              }
            }
          end

          def import_first_name(order, single_row, single_map)
            name = get_row_data(single_row, single_map)
            if  mapping['lastname'].nil? ||
                mapping['lastname'][:position] == 0
              arr = name.blank? ? [] : name.split(' ')
              order.firstname = arr.shift
              order.lastname = arr.join(' ')
            else
              order.firstname = name
            end
          end

          def update_status_and_save(order)
            order.status = 'onhold'
            order.save!
            order.addactivity(
              'Order Import CSV Import',
              Store.find(params[:store_id]).name + ' Import')
            order.update_order_status
          end

          def update_count_error_result(import_item, result, messages)
            result[:status] = false
            result[:messages] = messages
            import_item.status = 'failed'
            import_item.message = messages
            import_item.save
            result
          end
        end
      end
    end
  end
end
