module Groovepacker
  module Stores
    module Importers
      module CSV
        class ProductsImporter < CsvBaseImporter
          include ProductsHelper

          def import
            build_initial
            build_usable_records
            self.final_record.clear
            prepare_to_import
            return true if import_or_overwrite_prod == true
            @success_imported = @products_to_import.length
            @usable_records.clear
            @found_skus = nil

            Product.import @products_to_import
            found_products_raw = Product.find_all_by_store_product_id(@all_unique_ids)
            found_products = {}
            found_products_raw.each do |product|
              found_products[product.store_product_id] = product.id
            end
            found_products_raw = nil
            @all_unique_ids.clear

            @success = 0
            @product_import.status = 'processing_rest'
            @product_import.success = @success
            @product_import.current_sku = ''
            @product_import.total = @to_import_records.length
            @product_import.save

            collect_related_data_for_new_prod(found_products)
            @to_import_records.clear
            found_products = nil
            @found_barcodes.clear

            import_product_related_data
            update_orders_status
            @result
          end

          def build_initial
            @result = self.build_result
            @check_length = check_after_every(self.final_record.length)
            @success = 0
            @success_imported = 0
            @success_updated = 0
            @duplicate_file = 0
            @duplicate_db = 0
            @duplicate_action = 'skip'
            @new_action = 'skip'
            set_actions
            @product_import = set_find_product_import
            @all_skus = []
            @all_barcodes = []
            @usable_records = []
            @products_for_status_update = []
            @default_inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id
            @store_product_id_base = 'csv_import_'+self.params[:store_id].to_s+'_'+SecureRandom.uuid+'_'
          end

          def set_actions
            unless self.import_action.nil?
              if ['update_existing', 'create_update'].include?(self.import_action)
                @duplicate_action = 'overwrite'
              end

              if ['create_new', 'create_update'].include?(self.import_action)
                @new_action = 'create'
              end
            end
          end

          def set_find_product_import
            product_import = CsvProductImport.find_by_store_id(self.params[:store_id])
            if product_import.nil?
              product_import = CsvProductImport.new
              product_import.store_id = self.params[:store_id]
            end
            product_import.status = 'processing_csv'
            product_import.success = @success
            product_import.current_sku = ''
            product_import.total = self.final_record.length
            product_import.save
            return product_import
          end

          def init_usable_record(index)
            {
              name: '',
              weight: 0,
              skus: [],
              barcodes: [],
              store_product_id: @store_product_id_base+index.to_s,
              cats: [],
              images: [],
              inventory: [],
              product_type: '',
              spl_instructions_4_packer: '',
              is_intangible: false
            }
          end

          def build_single_row_skus(single_row)
            single_row_skus = []
            prim_skus = single_row[self.mapping['sku'][:position]].split(',')
            prim_skus.each do |prim_single_sku|
              single_row_skus << prim_single_sku.strip
            end
            if !self.mapping['secondary_sku'].nil? && self.mapping['secondary_sku'][:position] >= 0
              unless single_row[self.mapping['secondary_sku'][:position]].nil?
                sec_skus = single_row[self.mapping['secondary_sku'][:position]].split(',')
                sec_skus.each do |sec_single_sku|
                  unless single_row_skus.include? sec_single_sku.strip
                    single_row_skus << sec_single_sku.strip
                  end
                end
              end
            end
            if !self.mapping['tertiary_sku'].nil? && self.mapping['tertiary_sku'][:position] >= 0
              unless single_row[self.mapping['tertiary_sku'][:position]].nil?
                tert_skus = single_row[self.mapping['tertiary_sku'][:position]].split(',')
                tert_skus.each do |tert_single_sku|
                  unless single_row_skus.include? tert_single_sku.strip
                    single_row_skus << tert_single_sku.strip
                  end
                end
              end
            end
            single_row_skus
          end

          def apply_intangible(usable_record)
            scan_pack_settings = ScanPackSetting.all.first
            if scan_pack_settings.intangible_setting_enabled
              unless scan_pack_settings.intangible_string.nil? || (scan_pack_settings.intangible_string.strip.equal? (''))
                intangible_strings = scan_pack_settings.intangible_string.strip.split(",")
                intangible_strings.each do |string|
                  if (usable_record[:name].include? (string))
                    return true
                  end
                  usable_record[:skus].each do |sku|
                    if (sku.include? (string))
                      return true
                    end
                  end
                end
              end
            end
            return false
          end

          def init_prod_inv
            {
              inventory_warehouse_id: @default_inventory_warehouse_id,
              quantity_on_hand: 0,
              location_primary: '',
              location_secondary: '',
              location_tertiary: ''
            } 
          end

          def build_prod_inv(product_inventory,single_row)
            if !self.mapping['inv_wh1'].nil? && self.mapping['inv_wh1'][:position] >= 0
              product_inventory[:quantity_on_hand] = single_row[self.mapping['inv_wh1'][:position]] || ''
            end
            if !self.mapping['location_primary'].nil? && self.mapping['location_primary'][:position] >= 0
              product_inventory[:location_primary] = single_row[self.mapping['location_primary'][:position]] || ''
            end
            if !self.mapping['location_secondary'].nil? && self.mapping['location_secondary'][:position] >= 0
              product_inventory[:location_secondary] = single_row[self.mapping['location_secondary'][:position]] || ''
            end
            if !self.mapping['location_tertiary'].nil? && self.mapping['location_tertiary'][:position] >= 0
              product_inventory[:location_tertiary] = single_row[self.mapping['location_tertiary'][:position]] || ''
            end
            product_inventory
          end

          def build_usable_record(usable_record,single_row)
            if !self.mapping['product_name'].nil? && self.mapping['product_name'][:position] >= 0 && !single_row[self.mapping['product_name'][:position]].blank?
              usable_record[:name] = single_row[self.mapping['product_name'][:position]]
            end
            
            if !self.mapping['product_weight'].nil? && self.mapping['product_weight'][:position] >= 0 && !single_row[self.mapping['product_weight'][:position]].blank? && !single_row[self.mapping['product_weight'][:position]].nil?
              usable_record[:weight] = single_row[self.mapping['product_weight'][:position]]
            end
            if self.params[:use_sku_as_product_name]
              usable_record[:name] = single_row[self.mapping['sku'][:position]].strip
            end
            usable_record[:is_intangible] = apply_intangible(usable_record)
            
            if !self.mapping['product_instructions'].nil? && self.mapping['product_instructions'][:position] >= 0 && !single_row[self.mapping['product_instructions'][:position]].blank?
              usable_record[:spl_instructions_4_packer] = single_row[self.mapping['product_instructions'][:position]]
            end

            if !self.mapping['receiving_instructions'].nil? && self.mapping['receiving_instructions'][:position] >= 0 && !single_row[self.mapping['receiving_instructions'][:position]].blank?
              usable_record[:product_receiving_instructions] = single_row[self.mapping['receiving_instructions'][:position]]
            end

            if !self.mapping['barcode'].nil? && self.mapping['barcode'][:position] >= 0
              unless single_row[self.mapping['barcode'][:position]].nil?
                barcodes = single_row[self.mapping['barcode'][:position]].split(',')
                barcodes.each do |single_barcode|
                  break unless ProductBarcode.where(:barcode => single_barcode.strip).empty? && (!@all_barcodes.include? single_barcode.strip)
                  @all_barcodes << single_barcode.strip
                  usable_record[:barcodes] << single_barcode.strip
                end
              end
            elsif self.params[:generate_barcode_from_sku]
              barcodes = single_row[self.mapping['sku'][:position]].split(',')
              barcodes.each do |single_barcode|
                @all_barcodes << single_barcode.strip
                usable_record[:barcodes] << single_barcode.strip
              end
            end

            if !self.mapping['secondary_barcode'].nil? && self.mapping['secondary_barcode'][:position] >= 0
              unless single_row[self.mapping['secondary_barcode'][:position]].nil?
                secondary_barcodes = single_row[self.mapping['secondary_barcode'][:position]].split(',')
                secondary_barcodes.each do |single_secondary_barcode|
                  break unless ProductBarcode.where(:barcode => single_secondary_barcode.strip).empty? && (!@all_barcodes.include? single_secondary_barcode.strip)
                  @all_barcodes << single_secondary_barcode.strip
                  usable_record[:barcodes] << single_secondary_barcode.strip
                end
              end
            end

            if !self.mapping['tertiary_barcode'].nil? && self.mapping['tertiary_barcode'][:position] >= 0
              unless single_row[self.mapping['tertiary_barcode'][:position]].nil?
                tertiary_barcodes = single_row[self.mapping['tertiary_barcode'][:position]].split(',')
                tertiary_barcodes.each do |single_tertiary_barcode|
                  break unless ProductBarcode.where(:barcode => single_tertiary_barcode.strip).empty? && (!@all_barcodes.include? single_tertiary_barcode.strip)
                  @all_barcodes << single_tertiary_barcode.strip
                  usable_record[:barcodes] << single_tertiary_barcode.strip
                end
              end
            end

            if !self.mapping['product_type'].nil? && self.mapping['product_type'][:position] >= 0
              usable_record[:product_type] = single_row[self.mapping['product_type'][:position]]
            end
            #add inventory warehouses
            product_inventory = init_prod_inv
            
            usable_record[:inventory] << build_prod_inv(product_inventory,single_row)

            #add product categories
            if !self.mapping['category_name'].nil? && self.mapping['category_name'][:position] >= 0
              unless single_row[self.mapping['category_name'][:position]].nil?
                usable_record[:cats] = single_row[self.mapping['category_name'][:position]].split(',')
              end
            end

            if !self.mapping['product_images'].nil? && self.mapping['product_images'][:position] >= 0
              unless single_row[self.mapping['product_images'][:position]].nil?
                usable_record[:images] = single_row[self.mapping['product_images'][:position]].split(',')
              end
            end
            usable_record
          end

          def prepare_to_import
            found_skus_raw = ProductSku.find_all_by_sku(@all_skus)
            @found_skus = {}
            found_barcodes_raw = ProductBarcode.find_all_by_barcode(@all_barcodes)
            @found_barcodes = []
            found_skus_raw.each do |found_sku|
              @found_skus[found_sku.sku] = found_sku
              if @duplicate_action !='overwrite'
                @duplicate_db += 1
              end
            end
            found_barcodes_raw.each do |found_barcode|
              @found_barcodes << found_barcode.barcode
            end
            found_skus_raw = nil
            found_barcodes_raw = nil
            @all_skus.clear
            @all_barcodes.clear

            @products_to_import = []

            @to_import_records = []
            @all_unique_ids = []

            @import_product_skus = []
            @import_product_images = []
            @import_product_barcodes = []
            @import_product_cats = []
            @import_product_inventory_warehouses = []
          end

          def create_single_import(record)
            record[:name] = 'Product from CSV Import' if record[:name].blank?
            single_import = Product.new(:name => record[:name], :product_type => record[:product_type], :spl_instructions_4_packer => record[:spl_instructions_4_packer], :product_receiving_instructions => record[:product_receiving_instructions], :is_intangible => record[:is_intangible], :weight => record[:weight])
            single_import.store_id = self.params[:store_id]
            single_import.store_product_id = record[:store_product_id]
            if record[:skus].length > 0 && record[:barcodes].length > 0
              single_import.status = 'active'
            else
              single_import.status = 'new'
            end
            single_import
          end

          def delete_existing_prod(duplicate_product)
            product_info = {}
            product_info[:select_all] = false
            product_info[:inverted] = false
            product_info[:productArray] = []
            product_info[:productArray] << duplicate_product
            bulk_actions = Groovepacker::Products::BulkActions.new
            groove_bulk_actions = GrooveBulkActions.new
            groove_bulk_actions.identifier = 'product'
            groove_bulk_actions.activity = 'delete'
            groove_bulk_actions.save

            bulk_actions.delete(Apartment::Tenant.current, product_info, groove_bulk_actions.id, "during csv product import")
          end

          def update_existing_prod(duplicate_found, record, index)
            single_product_duplicate_sku = ProductSku.find_by_sku(duplicate_found)
            duplicate_product = Product.find_by_id(single_product_duplicate_sku.product_id)
            if record[:name] == "`[DELETE]`"
              delete_existing_prod(duplicate_product)
              return true
            end
            duplicate_product.store_id = self.params[:store_id]
            if !self.mapping['product_name'].nil? && record[:name]!=''
              duplicate_product.name = record[:name]
            end
            if !self.mapping['product_weight'].nil? #&& self.mapping['product_weight'][:action] == 'overwrite'
              duplicate_product.weight = record[:weight] if record[:weight].to_f > 0
            end
            duplicate_product.is_intangible = record[:is_intangible]
            if !self.mapping['product_type'].nil? #&& self.mapping['product_type'][:action] == 'overwrite'
              duplicate_product.product_type = record[:product_type]
            end
            if !self.mapping['product_instructions'].nil? #&& self.mapping['product_instructions'][:action] == 'overwrite'
              duplicate_product.spl_instructions_4_packer = record[:spl_instructions_4_packer]
            end
            if !self.mapping['receiving_instructions'].nil? #&& self.mapping['receiving_instructions'][:action] == 'overwrite'
              duplicate_product.product_receiving_instructions = record[:product_receiving_instructions]
            end

            @products_for_status_update << duplicate_product
            duplicate_product.save!
            @success_updated += 1

            if (!self.mapping['inv_wh1'].nil? || !self.mapping['location_primary'].nil? || !self.mapping['location_secondary'].nil? || !self.mapping['location_tertiary'].nil?)
              default_inventory = ProductInventoryWarehouses.find_or_create_by_inventory_warehouse_id_and_product_id(@default_inventory_warehouse_id, duplicate_product.id)
              updatable_record = record[:inventory].first
              if !self.mapping['inv_wh1'].nil? #&& self.mapping['inv_wh1'][:action] =='overwrite'
                default_inventory.quantity_on_hand = updatable_record[:quantity_on_hand]
              end
              if !self.mapping['location_primary'].nil? #&& self.mapping['location_primary'][:action] =='overwrite'
                default_inventory.location_primary = updatable_record[:location_primary]
              end
              if !self.mapping['location_secondary'].nil? #&& self.mapping['location_secondary'][:action] =='overwrite'
                default_inventory.location_secondary = updatable_record[:location_secondary]
              end
              if !self.mapping['location_tertiary'].nil? #&& self.mapping['location_tertiary'][:action] =='overwrite'
                default_inventory.location_tertiary = updatable_record[:location_tertiary]
              end
              default_inventory.save
            end


            if !self.mapping['category_name'].nil? && record[:cats].length > 0
              #if self.mapping['category_name'][:action] == 'overwrite'
              #  ProductCat.where(product_id: duplicate_product.id).delete_all
              #end

              #if self.mapping['category_name'][:action] == 'add' || self.mapping['category_name'][:action] == 'overwrite'
              all_found_cats = ProductCat.where(product_id: duplicate_product.id)
              to_not_add_cats = []
              all_found_cats.each do |single_found_dup_cat|
                if record[:cats].include? single_found_dup_cat.category
                  to_not_add_cats << single_found_dup_cat.category
                end
              end
              record[:cats].each do |single_to_add_cat|
                unless to_not_add_cats.include?(single_to_add_cat)
                  to_add_cat = ProductCat.new
                  to_add_cat.category = single_to_add_cat
                  to_add_cat.product_id = duplicate_product.id
                  @import_product_cats << to_add_cat
                end
              end
              #end
            end
            if !self.mapping['barcode'].nil? && record[:barcodes].length > 0
              #if self.mapping['barcode'][:action] == 'overwrite'
              #  ProductBarcode.where(product_id: duplicate_product.id).delete_all
              #end
              #if self.mapping['barcode'][:action] == 'add' || self.mapping['barcode'][:action] == 'overwrite'
              all_found_barcodes = ProductBarcode.where(product_id: duplicate_product.id)
              to_not_add_barcodes = []
              all_found_barcodes.each do |single_found_dup_barcode|
                if record[:barcodes].include? single_found_dup_barcode.barcode
                  to_not_add_barcodes << single_found_dup_barcode.barcode
                end
              end
              record[:barcodes].each_with_index do |single_to_add_barcode, index|
                unless to_not_add_barcodes.include?(single_to_add_barcode)
                  to_add_barcode = ProductBarcode.new
                  to_add_barcode.barcode = single_to_add_barcode
                  to_add_barcode.order = index
                  to_add_barcode.product_id = duplicate_product.id
                  @import_product_barcodes << to_add_barcode
                end
              end
              #end
            end

            if !self.mapping['sku'].nil? && record[:skus].length > 0
              #if self.mapping['sku'][:action] == 'overwrite'
              #  ProductSku.where(product_id: duplicate_product.id).delete_all
              #end
              #if self.mapping['sku'][:action] == 'add' || self.mapping['sku'][:action] == 'overwrite'
              all_found_skus = ProductSku.where(product_id: duplicate_product.id)
              to_not_add_skus = []
              all_found_skus.each do |single_found_dup_sku|
                if record[:skus].include? single_found_dup_sku.sku
                  to_not_add_skus << single_found_dup_sku.sku
                end
              end
              record[:skus].each_with_index do |single_to_add_sku, index|
                unless to_not_add_skus.include?(single_to_add_sku)
                  to_add_sku = ProductSku.new
                  to_add_sku.sku = single_to_add_sku
                  to_add_sku.order = index
                  to_add_sku.product_id = duplicate_product.id
                  @import_product_skus << to_add_sku
                end
              end
              #end
            end

            if !self.mapping['product_images'].nil? && record[:images].length > 0
              #if self.mapping['product_images'][:action] == 'overwrite'
              #  ProductImage.where(product_id: duplicate_product.id).delete_all
              #end
              #if self.mapping['product_images'][:action] == 'add' || self.mapping['product_images'][:action] == 'overwrite'
              all_found_images = ProductImage.where(product_id: duplicate_product.id)
              if record[:images].first == "[DELETE]"
                delete_existing_images(all_found_images)
              else
                to_not_add_images = []
                all_found_images.each do |single_found_dup_image|
                  if record[:images].include? single_found_dup_image.image
                    to_not_add_images << single_found_dup_image.image
                  end
                end
                to_add_images = record[:images] - to_not_add_images
                unless to_add_images.empty?
                  to_add_images.each_with_index do |single_to_add_image, index|
                    if index == 0
                      duplicate_product.primary_image = single_to_add_image
                    else
                      to_add_image = ProductImage.new
                      to_add_image.image = single_to_add_image
                      to_add_image.order = index
                      to_add_image.product_id = duplicate_product.id
                      @import_product_images << to_add_image
                    end
                  end
                end
                # record[:images].each_with_index do |single_to_add_image, index|
                #   unless to_not_add_images.include?(single_to_add_image)
                #     to_add_image = ProductImage.new
                #     to_add_image.image = single_to_add_image
                #     to_add_image.order = index
                #     to_add_image.product_id = duplicate_product.id
                #     @import_product_images << to_add_image
                #   end
                # end
              end
              #end
            end
          end

          def build_usable_records
            # Calling Go lambda function
            # => Generate event parameter file
            @retry_count = 0
            slice_size = 100
            barcode_positions = mapping.values_at("barcode", "secondary_barcode", "tertiary_barcode").compact.map{|mp| mp[:position]}
            
            final_record.each_slice(slice_size) do |final_record_slice|
              barcodes = final_record_slice.map do |sr|
                sr.values_at(*barcode_positions).map { |bc| bc.split(',') if bc }.flatten
              end.flatten.compact.uniq
              barcodes_count = ProductBarcode.where(barcode: barcodes).group(:barcode).count
              time_stamp = Time.now.to_i
              event_file_path = "uploads/#{Apartment::Tenant.current}_product_importer_event_#{time_stamp}.json"
              event_data = {
                store_product_id_base: @store_product_id_base,
                mapping: mapping,
                barcodes_count: barcodes_count,
                scan_pack_settings: ScanPackSetting.select([:intangible_setting_enabled, :intangible_string]).first,
                final_record: final_record_slice,
                params: params.as_json(
                  only: [:use_sku_as_product_name, :generate_barcode_from_sku]
                  ).merge(
                    default_inventory_warehouse_id: @default_inventory_warehouse_id
                    )
              }
              begin
                File.open(event_file_path, "w"){|f| f.write(event_data.to_json)}
                return_data = JSON.parse(`apex -C vendor/gopacker invoke csv_product_importer_helper < #{event_file_path}`)
                usable_records = return_data["usable_records"].map do |record|
                  record = record.symbolize_keys
                  record[:inventory] = record[:inventory].try(:map, &:symbolize_keys)
                  record
                end

                duplicate_file, success, all_skus, all_barcodes =
                  return_data.values_at("duplicate_file", "success", "all_skus", "all_barcodes")
                File.delete(event_file_path)
              rescue Exception => e
                retry if (@retry_count += 1) < 5
                puts e.message
              end
              
              @usable_records.push(*usable_records)
              @duplicate_file += duplicate_file.to_i
              @success += success.to_i
              @all_skus.push(*all_skus)
              @all_barcodes.push(*all_barcodes)

              @product_import.reload
              @product_import.success = @success
              @product_import.current_sku = @all_skus.last
              if @product_import.cancel
                @product_import.status = 'cancelled'
                @product_import.save
                return true
              end
              @product_import.save
            end

            @success = 0
            @product_import.status = 'processing_products'
            @product_import.success = @success
            @product_import.current_sku = ''
            @product_import.total = @usable_records.length
            @product_import.save
              
            # self.final_record.each_with_index do |single_row, index|
            #   do_skip = true
            #   for i in 0..(single_row.length-1)
            #     do_skip = false unless single_row[i].blank?
            #     break unless do_skip              
            #   end
            #   next if do_skip
            #   if !self.mapping['sku'].nil? && self.mapping['sku'][:position] >= 0 && !single_row[self.mapping['sku'][:position]].blank?
            #     single_row_skus = build_single_row_skus(single_row)
                
            #     if (@all_skus & single_row_skus).length > 0
            #       @duplicate_file += 1
            #     else
            #       usable_record = init_usable_record(index)
            #       @all_skus += single_row_skus
            #       usable_record[:skus] = single_row_skus
            #       @usable_records << build_usable_record(usable_record,single_row)
            #       @success += 1
            #     end
            #   end

            #   if (index + 1) % @check_length === 0 || index === (self.final_record.length - 1)
            #     @product_import.reload
            #     @product_import.success = @success
            #     @product_import.current_sku = @all_skus.last
            #     if @product_import.cancel
            #       @product_import.status = 'cancelled'
            #       @product_import.save
            #       return true
            #     end
            #     if index === (self.final_record.length - 1)
            #       @success = 0
            #       @product_import.status = 'processing_products'
            #       @product_import.success = @success
            #       @product_import.current_sku = ''
            #       @product_import.total = @usable_records.length
            #     end
            #     @product_import.save
            #   end
            # end
          end

          def import_or_overwrite_prod
            @usable_records.each_with_index do |record, index|
              duplicate_found = false
              record[:skus].each do |sku|
                if @found_skus.has_key? sku
                  duplicate_found = sku
                  break
                end
              end

              if duplicate_found === false && @new_action == 'create'
                @products_to_import << create_single_import(record)
                @to_import_records << record
                @all_unique_ids << record[:store_product_id]
              elsif duplicate_found === false && @duplicate_action == 'overwrite'
                #skip the current record and move on to the next one.
                next
              elsif @duplicate_action == 'overwrite'
                #update the product directly
                next if update_existing_prod(duplicate_found, record, index)
              end
              @success += 1
              if (index + 1) % @check_length === 0 || index === (@usable_records.length - 1)
                @product_import.reload
                @product_import.success = @success
                @product_import.current_sku = record[:skus].last
                if @product_import.cancel
                  @product_import.status = 'cancelled'
                  @product_import.save
                  return true
                end
                if index === (@usable_records.length - 1)
                  @product_import.status = 'importing_products'
                end
                @product_import.save
              end
            end
          end

          def collect_related_data_for_new_prod(found_products)
            @to_import_records.each_with_index do |record, index|
              product_id = found_products[record[:store_product_id]]
              if product_id > 0
                if record[:skus].length > 0
                  record[:skus].each_with_index do |sku, sku_order|
                    product_sku = ProductSku.new
                    product_sku.sku = sku
                    product_sku.order = sku_order
                    product_sku.product_id = product_id
                    @import_product_skus << product_sku
                  end
                end

                if record[:barcodes].length > 0
                  record[:barcodes].each_with_index do |barcode, barcode_order|
                    unless @found_barcodes.include? barcode
                      product_barcode = ProductBarcode.new
                      product_barcode.barcode = barcode
                      product_barcode.order = barcode_order
                      product_barcode.product_id = product_id
                      @import_product_barcodes << product_barcode
                    end
                  end
                end

                if record[:images].length > 0
                  record[:images].each_with_index do |image, image_order|
                    product_image = ProductImage.new
                    product_image.image = image
                    product_image.order = image_order
                    product_image.product_id = product_id
                    @import_product_images << product_image
                  end
                end

                if record[:cats].length > 0
                  record[:cats].each do |cat|
                    product_cat = ProductCat.new
                    product_cat.category = cat
                    product_cat.product_id = product_id
                    @import_product_cats << product_cat
                  end
                end

                if record[:inventory].length > 0
                  record[:inventory].each do |warehouse|
                    product_inv_wh = ProductInventoryWarehouses.new
                    product_inv_wh.inventory_warehouse_id = warehouse[:inventory_warehouse_id]
                    product_inv_wh.location_primary = warehouse[:location_primary]
                    product_inv_wh.location_secondary = warehouse[:location_secondary]
                    product_inv_wh.location_tertiary = warehouse[:location_tertiary]
                    product_inv_wh.quantity_on_hand = warehouse[:quantity_on_hand]
                    product_inv_wh.product_id = product_id
                    @import_product_inventory_warehouses << product_inv_wh
                  end
                end
              end
              @success += 1
              if (index + 1) % @check_length === 0 || index === (@to_import_records.length - 1)
                @product_import.success = @success
                @product_import.current_sku = record[:skus].last
                if index === (@to_import_records.length - 1)
                  @product_import.status = 'importing_skus'
                end
                @product_import.save
              end
            end
          end

          def import_product_related_data
            ProductSku.import @import_product_skus

            @import_product_skus.clear
            @product_import.status = 'importing_barcodes'
            @product_import.save

            ProductBarcode.import @import_product_barcodes

            @import_product_barcodes.clear
            @product_import.status = 'importing_cats'
            @product_import.save

            ProductCat.import @import_product_cats

            @import_product_cats.clear
            @product_import.status = 'importing_images'
            @product_import.save

            ProductImage.import @import_product_images

            @import_product_images.clear
            @product_import.status = 'importing_inventory'
            @product_import.save

            ProductInventoryWarehouses.import @import_product_inventory_warehouses


            @import_product_inventory_warehouses.clear


            @product_import.status = 'processing_status'
            @product_import.save
            @products_for_status_update.each do |status_update_product|
              status_update_product.reload
              status_update_product.update_product_status
            end


            Product.where(:store_id => self.params[:store_id]).update_all(:store_product_id => 0)
            @product_import.success_imported = @success_imported
            @product_import.success_updated = @success_updated
            @product_import.duplicate_file = @duplicate_file
            @product_import.duplicate_db = @duplicate_db
            @product_import.status = 'completed'
            @product_import.save
          end

          def check_after_every(length)
            if length <= 1000
              return 5
            end
            if length <= 5000
              return 25
            end
            if length <= 10000
              return 50
            end
            return 100
          end

          def delete_existing_images(images)
            images.each do |image|
              image.destroy
            end
          end

        end
      end
    end
  end
end
