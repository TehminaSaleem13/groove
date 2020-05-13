module Groovepacker
  module Stores
    module Importers
      module CSV
        class ProductsImporter < CsvBaseImporter
          include ProductImporterHelper

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
            Product.last(@products_to_import.length).each { |product| product.add_product_activity("Product Import","#{product.store.try(:name)}") }
            found_products_raw = []
            @all_unique_ids.each_slice(20000) do |ids|
              found_products_raw << Product.find_all_by_store_product_id(ids)  
            end
            found_products_raw = found_products_raw.flatten
            # found_products_raw = Product.find_all_by_store_product_id(@all_unique_ids)
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

          def build_single_row_skus(single_row)
            single_row_skus = []
            prim_skus = single_row[self.mapping['sku'][:position]].split(',')
            prim_skus.each do |prim_single_sku|
              single_row_skus << prim_single_sku.strip
            end
            all_skus = %w(secondary_sku tertiary_sku quaternary_sku quinary_sku senary_sku)
            all_skus.each do |sku_type|
              set_single_row_skus(single_row, single_row_skus, sku_type)
            end
            single_row_skus
          end

          def map_barcodes(barcode, order, single_row, usable_record)
            if !self.mapping[barcode].nil? && self.mapping[barcode][:position] >= 0
              unless single_row[self.mapping[barcode][:position]].nil?
                barcodes = single_row[self.mapping[barcode][:position]].split(',')
                barcodes_qty = single_row[self.mapping["#{barcode}_qty"][:position]].split(',') rescue 1
                usable_record[:all_barcodes][order] = barcodes
                barcodes.each do |single_barcode|
                  usable_record[:all_barcodes_qty][single_barcode] = barcodes_qty
                  break unless ProductBarcode.where(:barcode => single_barcode.strip).empty? && (!@all_barcodes.include? single_barcode.strip)
                  @all_barcodes << single_barcode.strip
                  usable_record[:barcodes] << single_barcode.strip
                end
              end
            end
            usable_record[:barcodes]
          end

          def prepare_to_import
            found_skus_raw = []
            @all_skus.each_slice(20000) do |skus|
              found_skus_raw << ProductSku.find_all_by_sku(skus)  
            end
            found_skus_raw = found_skus_raw.flatten
            # found_skus_raw = ProductSku.find_all_by_sku(@all_skus)
            @found_skus = {}
            found_barcodes_raw = []
            @all_barcodes.each_slice(20000) do |barcodes|
              found_barcodes_raw << ProductBarcode.find_all_by_barcode(barcodes)  
            end
            found_barcodes_raw = found_barcodes_raw.flatten
            # found_barcodes_raw = ProductBarcode.find_all_by_barcode(@all_barcodes)
            @found_barcodes = []
            found_skus_raw.each do |found_sku|
              @found_skus[found_sku.sku] = found_sku
              @duplicate_db += 1 if @duplicate_action !='overwrite'
            end
            found_barcodes_raw.each do |found_barcode|
              @found_barcodes << found_barcode.barcode
            end
            found_skus_raw = nil
            found_barcodes_raw = nil
            set_nil_prepare_to_import_items
          end

          def create_single_import(record)
            record[:name] = 'Product from CSV Import' if record[:name].blank?

            record[:product_record_serial] = ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_record_serial]) ? true : false
            record[:product_second_record_serial] = ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_second_record_serial]) ? true : false

            single_import = Product.new(:name => record[:name], :product_type => record[:product_type], :packing_instructions => record[:packing_instructions], :packing_instructions_conf => record[:packing_instructions_conf], :product_receiving_instructions => record[:product_receiving_instructions], :is_intangible => record[:is_intangible], :weight => record[:weight], :record_serial => record[:product_record_serial], :second_record_serial => record[:product_second_record_serial], :click_scan_enabled => record[:click_scan_enabled], :is_skippable => record[:is_skippable], :add_to_any_order => record[:add_to_any_order], :type_scan_enabled => record[:type_scan_enabled], :custom_product_1 => record[:custom_product_1], :custom_product_2 => record[:custom_product_2], :custom_product_3 => record[:custom_product_3], :custom_product_display_1 =>  record[:custom_product_display_1], :custom_product_display_2 => record[:custom_product_display_2], :custom_product_display_3 => record[:custom_product_display_3])
                        
            single_import.packing_placement = record[:packing_placement] if record[:packing_placement].present? 
            single_import.store_id = self.params[:store_id]
            single_import.store_product_id = record[:store_product_id]
            single_import.status = (record[:skus].length > 0 && record[:barcodes].length > 0) ? 'active' : 'new'
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
            duplicate_product.name = record[:name] if !self.mapping['product_name'].nil? && record[:name]!='' && record[:name]!= "[DELETE]"
            if record[:product_second_record_serial] != nil
              duplicate_product.second_record_serial = ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_second_record_serial]) ? 1 : record[:product_second_record_serial].to_i 
              # if ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_second_record_serial])
              #   duplicate_product.second_record_serial = 1
              # else
              #   duplicate_product.second_record_serial = record[:product_second_record_serial].to_i
              # end
            else
              duplicate_product.second_record_serial = 0
            end

            if record[:product_record_serial] != nil
              duplicate_product.record_serial = ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_record_serial]) ? 1 : record[:product_record_serial].to_i
              # if ["ON","on","TRUE",true,"YES","yes","1" ].include?(record[:product_record_serial])
              #   duplicate_product.record_serial = 1
              # else
              #   duplicate_product.record_serial = record[:product_record_serial].to_i
              # end
            else
              duplicate_product.record_serial = 0
            end  
            if !self.mapping['product_weight'].nil? #&& self.mapping['product_weight'][:action] == 'overwrite'
              duplicate_product.weight = record[:weight] if record[:weight].to_f > 0
            end
            duplicate_product.is_intangible = record[:is_intangible]
            if !self.mapping['product_type'].nil? #&& self.mapping['product_type'][:action] == 'overwrite'
              duplicate_product.product_type = record[:product_type]
            end
            if !self.mapping['product_instructions'].nil? && record[:packing_instructions] != "[DELETE]"  #&& self.mapping['product_instructions'][:action] == 'overwrite'
              duplicate_product.packing_instructions = record[:packing_instructions]
            end
            if !self.mapping['receiving_instructions'].nil? && record[:product_receiving_instructions] != "[DELETE]" #&& self.mapping['receiving_instructions'][:action] == 'overwrite'
              duplicate_product.product_receiving_instructions = record[:product_receiving_instructions]
            end
            
            assign_duplicate_product_attributes(record, duplicate_product)
            
            @products_for_status_update << duplicate_product
            duplicate_product.save!
            @success_updated += 1

            if (!self.mapping['inv_wh1'].nil? || !self.mapping['location_primary'].nil? || !self.mapping['location_secondary'].nil? || !self.mapping['location_tertiary'].nil?)
              default_inventory = ProductInventoryWarehouses.find_or_create_by_inventory_warehouse_id_and_product_id(@default_inventory_warehouse_id, duplicate_product.id)
              updatable_record = record[:inventory].first
              if !self.mapping['inv_wh1'].nil? && updatable_record[:quantity_on_hand] != "[DELETE]" #&& self.mapping['inv_wh1'][:action] =='overwrite'
                default_inventory.quantity_on_hand = updatable_record[:quantity_on_hand]
              end

              attributes_location = %w(location_primary location_secondary location_tertiary)
              attributes_location.each do |location|
                default_inventory.send(location + '=', updatable_record[location.to_sym]) if !self.mapping[location].nil? && updatable_record[location.to_sym] != "[DELETE]"
              end

              # if !self.mapping['location_primary'].nil? && updatable_record[:location_primary] != "[DELETE]" #&& self.mapping['location_primary'][:action] =='overwrite'
              #   default_inventory.location_primary = updatable_record[:location_primary]
              # end
              # if !self.mapping['location_secondary'].nil? && updatable_record[:location_secondary] != "[DELETE]" #&& self.mapping['location_secondary'][:action] =='overwrite'
              #   default_inventory.location_secondary = updatable_record[:location_secondary]
              # end
              # if !self.mapping['location_tertiary'].nil? && updatable_record[:location_tertiary] != "[DELETE]" #&& self.mapping['location_tertiary'][:action] =='overwrite'
              #   default_inventory.location_tertiary = updatable_record[:location_tertiary]
              # end
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
                to_not_add_cats << single_found_dup_cat.category if record[:cats].include? single_found_dup_cat.category
              end
              record[:cats].each do |single_to_add_cat|
                if !to_not_add_cats.include?(single_to_add_cat) && single_to_add_cat != "[DELETE]"
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
                if !to_not_add_barcodes.include?(single_to_add_barcode) && single_to_add_barcode != "[DELETE]"
                  begin
                    to_add_barcode = ProductBarcode.new
                    to_add_barcode.barcode = single_to_add_barcode
                    to_add_barcode.packing_count = record[:all_barcodes_qty][single_to_add_barcode][0].to_i rescue 1
                    to_add_barcode.order = index
                    to_add_barcode.product_id = duplicate_product.id
                    to_add_barcode.save!
                    #@import_product_barcodes << to_add_barcode
                  rescue Exception => e
                    Rollbar.error(e, e.message) 
                  end
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
                if !to_not_add_skus.include?(single_to_add_sku) && single_to_add_sku != "[DELETE]" 
                  begin
                    to_add_sku = ProductSku.new
                    to_add_sku.sku = single_to_add_sku
                    to_add_sku.order = index
                    to_add_sku.product_id = duplicate_product.id
                    to_add_sku.save!
                    #@import_product_skus << to_add_sku
                  rescue Exception => e
                    Rollbar.error(e, e.message) 
                  end
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
            self.final_record.each_with_index do |single_row, index|
              do_skip = true
              for i in 0..(single_row.length - 1)
                do_skip = false unless single_row[i].blank?
                break unless do_skip
              end
              next if do_skip
              if !self.mapping['sku'].nil? && self.mapping['sku'][:position] >= 0 && !single_row[self.mapping['sku'][:position]].blank?
                single_row_skus = build_single_row_skus(single_row)
                (@all_skus & single_row_skus).length > 0 ? @duplicate_file += 1 : insert_usable_record_skus(index, single_row_skus, single_row)
              end
              update_new_product_attributes(index)
            end

            @success = 0
            @product_import.status = 'processing_products'
            @product_import.success = @success
            @product_import.current_sku = ''
            @product_import.total = @usable_records.length
            @product_import.save
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
              # product = Product.find_by_name(record[:name])
              if duplicate_found === false && @new_action == 'create'
                product = find_product(record)
                if product.present?
                  delete_product(record) rescue nil
                else
                  @products_to_import << create_single_import(record)
                  @to_import_records << record
                  @all_unique_ids << record[:store_product_id]
                end
              elsif duplicate_found === false && @duplicate_action == 'overwrite'
                #skip the current record and move on to the next one.
                next
              elsif @duplicate_action == 'overwrite'
                overwrite_existing_product(record)
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
                @product_import.status = 'importing_products' if index === (@usable_records.length - 1)
                @product_import.save
              end
            end
          end

          def import_product_related_data
            #ProductSku.import @import_product_skus

            @import_product_skus.clear
            @product_import.status = 'importing_barcodes'
            @product_import.save
            
            #ProductBarcode.import @import_product_barcodes

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
            update_product_import_data
          end

          def update_product_import_data
            Product.where(:store_id => self.params[:store_id]).update_all(:store_product_id => 0)
            @product_import.success_imported = @success_imported
            @product_import.success_updated = @success_updated
            @product_import.duplicate_file = @duplicate_file
            @product_import.duplicate_db = @duplicate_db
            @product_import.status = 'completed'
            @product_import.save
          end

          def set_nil_prepare_to_import_items
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

          def set_single_row_skus(single_row, single_row_skus, sku_type)
            if !self.mapping["#{sku_type}"].nil? && self.mapping["#{sku_type}"][:position] >= 0
              unless single_row[self.mapping["#{sku_type}"][:position]].nil?
                other_skus = single_row[self.mapping["#{sku_type}"][:position]].split(',')
                other_skus.each do |other_single_sku|
                  single_row_skus << other_single_sku.strip unless single_row_skus.include? other_single_sku.strip
                end
              end
            end
          end

          def update_new_product_attributes(index)
            return @product_import.save unless (index + 1) % @check_length === 0 || index === (self.final_record.length - 1)
            @product_import.reload
            @product_import.success = @success
            @product_import.current_sku = @all_skus.last
            if @product_import.cancel
              @product_import.status = 'cancelled'
              @product_import.save
              return true
            end
            if index === (self.final_record.length - 1)
              @success = 0
              @product_import.status = 'processing_products'
              @product_import.success = @success
              @product_import.current_sku = ''
              @product_import.total = @usable_records.length
            end
            # return true
            @product_import.save
          end

          def insert_usable_record_skus(index, single_row_skus, single_row)
            usable_record = init_usable_record(index)
            @all_skus += single_row_skus
            usable_record[:skus] = single_row_skus
            begin
              usable_record[:new_sku] = []

              sku_types = %w(sku secondary_sku tertiary_sku quaternary_sku quinary_sku senary_sku)
              sku_types.each do |single_sku_type|
                usable_record[:new_sku] << single_row[self.mapping[single_sku_type][:position]].split(',')[0] rescue nil
              end
              # usable_record[:new_sku] <<  single_row[self.mapping['sku'][:position]].split(',')[0]
              # usable_record[:new_sku] <<  single_row[self.mapping['secondary_sku'][:position]].split(',')[0] rescue nil
              # usable_record[:new_sku] <<  single_row[self.mapping['tertiary_sku'][:position]].split(',')[0] rescue nil
              # usable_record[:new_sku] <<  single_row[self.mapping['quaternary_sku'][:position]].split(',')[0] rescue nil
              # usable_record[:new_sku] <<  single_row[self.mapping['quinary_sku'][:position]].split(',')[0] rescue nil
              # usable_record[:new_sku] <<  single_row[self.mapping['senary_sku'][:position]].split(',')[0] rescue nil
            rescue Exception => e
              Rollbar.error(e, e.message)
            end
            @usable_records << build_usable_record(usable_record, single_row)
            @success += 1
          end

          def assign_duplicate_product_attributes(record, duplicate_product)
            attributes1 = %W(click_scan_enabled type_scan_enabled custom_product_display_1 custom_product_display_2 custom_product_display_3 is_skippable add_to_any_order)
            attributes1.each do |attribute_name|
              duplicate_product.send(attribute_name + '=', record[attribute_name.to_sym]) if !self.mapping[attribute_name].nil? && record[attribute_name.to_sym] != "[DELETE]"
            end

            # if !self.mapping['click_scan_enabled'].nil? && record[:click_scan_enabled] != "[DELETE]"
            #   duplicate_product.click_scan_enabled = record[:click_scan_enabled]
            # end

            # if !self.mapping['type_scan_enabled'].nil? && record[:type_scan_enabled] != "[DELETE]"
            #   duplicate_product.type_scan_enabled = record[:type_scan_enabled]
            # end

            # if !self.mapping['custom_product_display_1'].nil? && record[:custom_product_display_1] != "[DELETE]"
            #   duplicate_product.custom_product_display_1 = record[:custom_product_display_1]
            # end

            # if !self.mapping['custom_product_display_2'].nil? && record[:custom_product_display_2] != "[DELETE]"
            #   duplicate_product.custom_product_display_2 = record[:custom_product_display_2]
            # end

            # if !self.mapping['custom_product_display_3'].nil? && record[:custom_product_display_3] != "[DELETE]"
            #   duplicate_product.custom_product_display_3 = record[:custom_product_display_3]
            # end

            # if !self.mapping['is_skippable'].nil? && record[:is_skippable] != "[DELETE]"
            #   duplicate_product.is_skippable = record[:is_skippable]
            # end

            # if !self.mapping['add_to_any_order'].nil? && record[:add_to_any_order] != "[DELETE]"
            #   duplicate_product.add_to_any_order = record[:add_to_any_order]
            # end

            attributes2 = %W(custom_product_1 custom_product_2 custom_product_3)
            attributes2.each do |attribute_name|
              duplicate_product.send(attribute_name + '=', record[attribute_name.to_sym]) if !self.mapping[attribute_name].nil? && record[attribute_name.to_sym] != '' && record[attribute_name.to_sym] != "[DELETE]"
            end

            # if !self.mapping['custom_product_1'].nil? && record[:custom_product_1]!='' && record[:custom_product_1]!= "[DELETE]"
            #   duplicate_product.custom_product_1 = record[:custom_product_1]
            # end

            # if !self.mapping['custom_product_2'].nil? && record[:custom_product_2]!='' && record[:custom_product_2]!= "[DELETE]"
            #   duplicate_product.custom_product_2 = record[:custom_product_2]
            # end

            # if !self.mapping['custom_product_3'].nil? && record[:custom_product_3]!='' && record[:custom_product_3]!= "[DELETE]"
            #   duplicate_product.custom_product_3 = record[:custom_product_3]
            # end
          end

          def delete_product(record)
            product = find_product(record)
            record[:new_sku].each_with_index do |sku, new_order|
              product.product_skus.find_by_order(new_order).destroy if sku == "[DELETE]" && product.product_skus.count > 1 rescue nil
            end
            (product.try(:product_skus) || []).each_with_index do |sku, index|
              sku.order = index
              sku.save
            end
          end

        end
      end
    end
  end
end
