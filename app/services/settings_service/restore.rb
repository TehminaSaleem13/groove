module SettingsService
  class Restore < SettingsService::Base
    attr_reader :current_user, :params, :products_to_check_later,
                :result

    def initialize(current_user: nil, params: nil)
      @current_user = current_user
      @params = params
      @products_to_check_later = []
      @result = {
        'status' => true,
        'messages' => []
      }
    end

    def call
      if current_user.can? 'restore_backups'
        process_restore if valid_params?
      else
        generate_fail_message('User cannot restore backups')
      end
      super
    end

    private

    def generate_fail_message(msg)
      @result['status'] = false
      @result['messages'].push(msg)
    end

    def process_restore
      mapping, default_warehouse_map = load_mappings

      require 'zip'
      require 'csv'

      # Clear tables if delete method is invoked
      delete_table_data(mapping)

      # Open uploaded zip file
      Zip::File.open(params[:file].path) do |zipfile|
        # For each csv in the zip
        zipfile.each do |file|
          # Remove .csv extension to check if we have mapping defined for it
          current_mapping = file.name.chomp('.csv')

          next unless mapping.key?(current_mapping)
          # Parse the file by it's data
          parse_csv_file(file, zipfile, mapping, default_warehouse_map, current_mapping)
        end
      end
      products_to_check_later.each(&:update_product_status)
    end

    def load_mappings
      default_warehouse_map = {
        'QOH' => 'available_inv',
        'BinLocation 1' => 'location_primary',
        'BinLocation 2' => 'location_secondary'
      }
      # end
      mapping = YAML.load_file('config/data_mappings/restore_map.yml')
      [mapping, default_warehouse_map]
    end

    def valid_params?
      if !params[:method].eql?('del_import')
        generate_fail_message('No action selected')
      elsif params[:file].blank?
        generate_fail_message('No file selected')
      end
      @result['status']
    end

    def delete_table_data(mapping)
      mapping.each { |single_map| single_map[1][:model].constantize.delete_all }
    end

    def parse_csv_file(file, zipfile, mapping, default_warehouse_map, current_mapping)
      CSV.parse(zipfile.read(file.name), headers: true) do |csv_row|
        create_new, single_row = find_by_mapping_model(
          current_mapping, mapping, csv_row, single_row
        )

        next if single_row.blank?

        # Now loop through all our defined mappings to check and update values
        check_and_update_values(
          current_mapping, mapping, csv_row, single_row, create_new
        )

        single_row.save

        if current_mapping == 'products'
          single_row.attributes = csv_row.as_json(
            only: %w(primary_sku primary_barcode primary_category primary_image)
          )

          find_or_create_product_inventory(
            single_row, csv_row, default_warehouse_map
          )

          products_to_check_later << single_row unless csv_row['is_kit'].blank?
        end
      end
    end

    def find_by_mapping_model(
      current_mapping, mapping, csv_row,
      single_row
    )
      query = generate_query(current_mapping, csv_row)

      single_row = mapping[current_mapping][:model].constantize.where(
        query.merge(product_id: csv_row['product_id'])
      ).first if query

      return [false, single_row] if single_row.present?
      single_row = mapping[current_mapping][:model].constantize.new
      [true, single_row]
    end

    def generate_query(current_mapping, csv_row)
      if current_mapping == 'product_barcodes'
        { barcode: csv_row['barcode'].strip }
      elsif current_mapping == 'product_skus'
        { sku: csv_row['sku'].strip }
      elsif current_mapping == 'product_cats'
        { category: csv_row['category'].try(:strip) }
      elsif current_mapping == 'product_images'
        { image: csv_row['image'] }
      elsif current_mapping == 'product_inventory_warehouses'
        { inventory_warehouse_id: csv_row['inventory_warehouse_id'] }
      end
    end

    def check_and_update_values(
      current_mapping, mapping, csv_row, single_row, create_new
    )
      mapping[current_mapping][:map].each do |column|
        column_first = column[0]
        column_second = column[1]
        csv_row_first_column = csv_row[column_first]
        if current_mapping == 'product_skus' && column_second == 'id' && !create_new
          break
        end

        # If mapping's CSV index is present, update row
        if csv_row_first_column.blank?
          do_if_first_column_blank(current_mapping, column_second, single_row)
        elsif current_mapping == 'products' && column_second != 'id'
          single_row[column_second] = if in_list?(column_first)
                                        csv_row_first_column.strip
                                      else
                                        csv_row_first_column
                                      end
        end
        # Add special mapping rules here. current_mapping is
        # the key of mapping variable above
        # single_row is the selected row of model marked under
        # mapping[current_mapping]
        # column[0] is csv_header column[1] is db_table_header
        # happy coding!
      end
    end

    def do_if_first_column_blank(current_mapping, column_second, single_row)
      return unless current_mapping == 'products' && column_second == 'name'
      single_row['name'] = 'Product from Restore'
    end

    def in_list?(column_first)
      column_first.in? %w(barcode sku category)
    end

    def find_or_create_product_inventory(
      single_row, csv_row, default_warehouse_map
    )
      warehouse = ProductInventoryWarehouses
                  .find_or_create_by_product_id_and_inventory_warehouse_id(
                    single_row.id,
                    InventoryWarehouse.where(is_default: true).first.id
                  )
      default_warehouse_map.each do |warehouse_map|
        warehouse[warehouse_map[1]] = csv_row[warehouse_map[0]]
      end
      warehouse.save
    end
  end
end
