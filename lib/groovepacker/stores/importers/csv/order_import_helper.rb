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
                lastname method postcode sku state price tracking_num qty)
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
              !params[:order_date_time_format].nil? &&
              params[:order_date_time_format] != 'Default'
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
        end
      end
    end
  end
end
