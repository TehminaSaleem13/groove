module SettingsService
  class Restore < SettingsService::Base
    attr_reader :current_user, :params

    def initialize(current_user: nil, params: nil)
      @current_user = current_user
      @params = params
    end

    def call
      process_restore
      super
    end

    private

    def process_restore
      @result = Hash.new
      @result['status'] = true
      @result['messages'] = []
      if current_user.can? 'restore_backups'
        # Every entry on mapping[current_mapping][:map] should be in the format
        # csv_header => db_table_header
        # if params[:method] == 'del_import_old'
        #   product_map = {
        #     'id' => 'id',
        #     'store_product_id' => 'store_product_id',
        #     'name' => 'name',
        #     'product_type' => 'product_type',
        #     'store_id' => 'store_id',
        #     'created_at' => 'created_at',
        #     'updated_at' => 'updated_at',
        #     'inv_wh1' => 'inv_wh1',
        #     'status' => 'status',
        #     'spl_instructions_4_packer' => 'spl_instructions_4_packer',
        #     'spl_instructions_4_confirmation' => 'spl_instructions_4_confirmation',
        #     'barcode' => 'barcode',
        #     'is_skippable' => 'is_skippable',
        #     'packing_placement' => 'packing_placement',
        #     'pack_time_adj' => 'pack_time_adj',
        #     'kit_parsing' => 'kit_parsing',
        #     'is_kit' => 'is_kit',
        #     'disable_conf_req' => 'disable_conf_req',
        #     'total_avail_ext' => 'total_avail_ext',
        #     'weight' => 'weight',
        #     'shipping_weight' => 'shipping_weight'
        #   }
        #   default_warehouse_map = {
        #     'default_wh_avbl' => 'available_inv',
        #     'default_wh_loc_primary' => 'location_primary',
        #     'default_wh_loc_secondary' => 'location_secondary'
        #   }
        # else
          product_map = {
            'ID' => 'id',
            'Name' => 'name',
            'store_product_id' => 'store_product_id',
            'product_type' => 'product_type',
            'store_id' => 'store_id',
            'created_at' => 'created_at',
            'updated_at' => 'updated_at',
            'BinLocation 1' => 'inv_wh1',
            'status' => 'status',
            'spl_instructions_4_packer' => 'spl_instructions_4_packer',
            'spl_instructions_4_confirmation' => 'spl_instructions_4_confirmation',
            'Barcode 1' => 'barcode',
            'is_skippable' => 'is_skippable',
            'packing_placement' => 'packing_placement',
            'pack_time_adj' => 'pack_time_adj',
            'kit_parsing' => 'kit_parsing',
            'is_kit' => 'is_kit',
            'disable_conf_req' => 'disable_conf_req',
            'total_avail_ext' => 'total_avail_ext',
            'Weight' => 'weight',
            'shipping_weight' => 'shipping_weight'
          }
          default_warehouse_map = {
            'QOH' => 'available_inv',
            'BinLocation 1' => 'location_primary',
            'BinLocation 2' => 'location_secondary'
          }
        # end
        mapping = {
          'products' => {
            model: Product,
            map: product_map
          },

          'product_barcodes' => {
            model: ProductBarcode,
            map: {
              'id' => 'id',
              'product_id' => 'product_id',
              'barcode' => 'barcode',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at',
              'order' => 'order'
            }
          },
          'product_images' => {
            model: ProductImage,
            map: {
              'id' => 'id',
              'product_id' => 'product_id',
              'image' => 'image',
              'caption' => 'caption',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at',
              'order' => 'order'
            }
          },
          'product_skus' => {
            model: ProductSku,
            map: {
              'id' => 'id',
              'product_id' => 'product_id',
              'sku' => 'sku',
              'purpose' => 'purpose',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at',
              'order' => 'order'
            }
          },
          'product_cats' => {
            model: ProductCat,
            map: {
              'id' => 'id',
              'category' => 'category',
              'product_id' => 'product_id',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at'
            }
          },
          'product_kit_skus' => {
            model: ProductKitSkus,
            map: {
              'id' => 'id',
              'option_product_id' => 'option_product_id',
              'qty' => 'qty',
              'product_id' => 'product_id',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at',
              'packing_order' => 'packing_order'
            }
          },
          'product_inventory_warehouses' => {
            model: ProductInventoryWarehouses,
            map: {
              'id' => 'id',
              'location' => 'location',
              'qty' => 'qty',
              'product_id' => 'product_id',
              'created_at' => 'created_at',
              'updated_at' => 'updated_at',
              'alert' => 'alert',
              'location_primary' => 'location_primary',
              'location_secondary' => 'location_secondary',
              'name' => 'name',
              'inventory_warehouse_id' => 'inventory_warehouse_id',
              'available_inv' => 'available_inv',
              'allocated_inv' => 'allocated_inv'
            }
          }
        }

        if params[:method].nil? || !['del_import'].include?(params[:method])
          @result['status'] = false
          @result['messages'].push("No action selected")
        elsif params[:file].nil?
          @result['status'] = false
          @result['messages'].push("No file selected")
        else
          require 'zip'
          require 'csv'
          # Clear tables if delete method is invoked
          mapping.each do |single_map|
            single_map[1][:model].delete_all
          end

          products_to_check_later = []
          # Open uploaded zip file
          Zip::File.open(params[:file].path) do |zipfile|
            # For each csv in the zip
            zipfile.each do |file|
              # Remove .csv extension to check if we have mapping defined for it
              current_mapping = file.name.chomp(".csv")
              if mapping.key?(current_mapping)
                # Parse the file by it's data
                CSV.parse(zipfile.read(file.name), :headers => true) do |csv_row|
                  single_row = nil
                  create_new = false
                  # Create new row if deleted all else find and select by id for updating
                  # if params[:method] == 'del_import'
                  if current_mapping == 'product_barcodes'
                    all_rows = mapping[current_mapping][:model].where(:barcode => csv_row['barcode'].strip, :product_id => csv_row['product_id'])
                    if all_rows.length >0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_skus'
                    all_rows = mapping[current_mapping][:model].where(:sku => csv_row['sku'].strip, :product_id => csv_row['product_id'])
                    if all_rows.length >0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_cats'
                    all_rows = mapping[current_mapping][:model].where(:category => csv_row['category'].strip, :product_id => csv_row['product_id'])
                    if all_rows.length >0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_images'
                    all_rows = mapping[current_mapping][:model].where(:image => csv_row['image'], :product_id => csv_row['product_id'])
                    if all_rows.length > 0
                      single_row = all_rows.first
                    end
                  elsif current_mapping == 'product_inventory_warehouses'
                    all_rows = mapping[current_mapping][:model].where(:inventory_warehouse_id => csv_row['inventory_warehouse_id'], :product_id => csv_row['product_id'])
                    if all_rows.length > 0
                      single_row = all_rows.first
                    end
                  end
                  if single_row.nil?
                    single_row = mapping[current_mapping][:model].new
                    create_new = true
                  end

                  unless single_row.nil?
                    # Now loop through all our defined mappings to check and update values
                    mapping[current_mapping][:map].each do |column|
                      if current_mapping=='product_skus' && column[1] =='id' && !create_new
                        break;
                      end
                      # If mapping's CSV index is present, update row
                      if csv_row[column[0]].blank?
                        if current_mapping=='products' && column[1] =='name'
                          single_row['name'] = 'Product from Restore'
                        end
                      elsif !(current_mapping != 'products' && column[1] =='id')
                        if ['barcode', 'sku', 'category'].include? column[0]
                          single_row[column[1]] = csv_row[column[0]].strip
                        else
                          single_row[column[1]] = csv_row[column[0]]
                        end
                      end
                      # Add special mapping rules here. current_mapping is the key of mapping variable above
                      # single_row is the selected row of model marked under mapping[current_mapping]
                      # column[0] is csv_header column[1] is db_table_header
                      # happy coding!
                    end
                    single_row.save
                    if current_mapping == 'products'
                      unless csv_row['primary_sku'].blank?
                        single_row.primary_sku = csv_row['primary_sku']
                      end
                      unless csv_row['primary_barcode'].blank?
                        single_row.primary_barcode = csv_row['primary_barcode']
                      end
                      unless csv_row['primary_category'].blank?
                        single_row.primary_category = csv_row['primary_category']
                      end
                      unless csv_row['primary_image'].blank?
                        single_row.primary_image = csv_row['primary_image']
                      end
                      warehouse = ProductInventoryWarehouses.find_or_create_by_product_id_and_inventory_warehouse_id(single_row.id, InventoryWarehouse.where(:is_default => true).first.id)
                      default_warehouse_map.each do |warehouse_map|
                        warehouse[warehouse_map[1]] = csv_row[warehouse_map[0]]
                      end
                      warehouse.save
                      unless csv_row['is_kit'].blank?
                        products_to_check_later << single_row
                      end
                    end
                  end
                end
              end
            end
          end
          products_to_check_later.each do |product|
            product.update_product_status
          end
        end
      else
        @result["status"] = false
        @result["messages"].push("User cannot restore backups")
      end
    end
  end
end
