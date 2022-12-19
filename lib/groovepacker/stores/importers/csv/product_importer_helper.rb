# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module CSV
        module ProductImporterHelper
          include ProductsHelper

          def set_actions
            unless import_action.nil?
              @duplicate_action = 'overwrite' if %w[update_existing create_update].include?(import_action)

              @new_action = 'create' if %w[create_new create_update].include?(import_action)
            end
          end

          def set_find_product_import
            product_import = CsvProductImport.find_by_store_id(params[:store_id])
            if product_import.nil?
              product_import = CsvProductImport.new
              product_import.store_id = params[:store_id]
            end
            product_import.status = 'processing_csv'
            product_import.success = @success
            product_import.current_sku = ''
            product_import.total = final_record.length
            product_import.save
            product_import
          end

          def init_usable_record(index)
            {
              name: '', weight: 0, skus: [], barcodes: [], store_product_id: @store_product_id_base + index.to_s,
              cats: [], images: [], inventory: [], product_type: '', packing_instructions: '',
              is_intangible: false, click_scan_enabled: 'on', is_skippable: false, add_to_any_order: false,
              type_scan_enabled: 'on', custom_product_1: '', custom_product_2: '', custom_product_3: '',
              custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false
            }
          end

          def build_usable_record(usable_record, single_row)
            if !mapping['product_name'].nil? && mapping['product_name'][:position] >= 0 && !single_row[mapping['product_name'][:position]].blank?
              usable_record[:name] = single_row[mapping['product_name'][:position]]
            end

            # if !self.mapping['product_weight'].nil? && self.mapping['product_weight'][:position] >= 0 && !single_row[self.mapping['product_weight'][:position]].blank? && !single_row[self.mapping['product_weight'][:position]].nil?
            #   usable_record[:weight] = single_row[self.mapping['product_weight'][:position]]
            # end

            usable_record[:name] = single_row[mapping['sku'][:position]].strip if params[:use_sku_as_product_name]
            usable_record[:is_intangible] = apply_intangible(usable_record)

            if !mapping['is_intangible'].nil? && mapping['is_intangible'][:position] >= 0 && !single_row[mapping['is_intangible'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['is_intangible'][:position]])
                usable_record[:is_intangible] = true
              end
            end

            if !mapping['click_scan_enabled'].nil? && mapping['click_scan_enabled'][:position] >= 0 && !single_row[mapping['click_scan_enabled'][:position]].blank?
              if ['OFF', 'off', 'FALSE', false, 'false', 'NO', 'no', '0'].include?(single_row[mapping['click_scan_enabled'][:position]])
                usable_record[:click_scan_enabled] = 'off'
              end
            end

            if !mapping['is_skippable'].nil? && mapping['is_skippable'][:position] >= 0 && !single_row[mapping['is_skippable'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['is_skippable'][:position]])
                usable_record[:is_skippable] = true
              end
            end

            if !mapping['packing_placement'].nil? && mapping['packing_placement'][:position] >= 0 && !single_row[mapping['packing_placement'][:position]].blank?
              usable_record[:packing_placement] = single_row[mapping['packing_placement'][:position]].to_i if single_row[mapping['packing_placement'][:position]].to_i > 0
            end

            if !mapping['add_to_any_order'].nil? && mapping['add_to_any_order'][:position] >= 0 && !single_row[mapping['add_to_any_order'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['add_to_any_order'][:position]])
                usable_record[:add_to_any_order] = true
              end
            end

            if !mapping['type_scan_enabled'].nil? && mapping['type_scan_enabled'][:position] >= 0 && !single_row[mapping['type_scan_enabled'][:position]].blank?
              if ['OFF', 'off', 'FALSE', false, 'false', 'NO', 'no', '0'].include?(single_row[mapping['type_scan_enabled'][:position]])
                usable_record[:type_scan_enabled] = 'off'
              end
            end

            if !mapping['custom_product_display_1'].nil? && mapping['custom_product_display_1'][:position] >= 0 && !single_row[mapping['custom_product_display_1'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['custom_product_display_1'][:position]])
                usable_record[:custom_product_display_1] = true
              end
            end

            if !mapping['custom_product_display_2'].nil? && mapping['custom_product_display_2'][:position] >= 0 && !single_row[mapping['custom_product_display_2'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['custom_product_display_2'][:position]])
                usable_record[:custom_product_display_2] = true
              end
            end

            if !mapping['custom_product_display_3'].nil? && mapping['custom_product_display_3'][:position] >= 0 && !single_row[mapping['custom_product_display_3'][:position]].blank?
              if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['custom_product_display_3'][:position]])
                usable_record[:custom_product_display_3] = true
              end
            end

            if !mapping['custom_product_1'].nil? && mapping['custom_product_1'][:position] >= 0 && !single_row[mapping['custom_product_1'][:position]].blank?
              usable_record[:custom_product_1] = single_row[mapping['custom_product_1'][:position]]
            end

            if !mapping['custom_product_2'].nil? && mapping['custom_product_2'][:position] >= 0 && !single_row[mapping['custom_product_2'][:position]].blank?
              usable_record[:custom_product_2] = single_row[mapping['custom_product_2'][:position]]
            end

            if !mapping['custom_product_3'].nil? && mapping['custom_product_3'][:position] >= 0 && !single_row[mapping['custom_product_3'][:position]].blank?
              usable_record[:custom_product_3] = single_row[mapping['custom_product_3'][:position]]
            end

            if !mapping['packing_instructions_conf'].nil? && mapping['packing_instructions_conf'][:position] >= 0 && !single_row[mapping['packing_instructions_conf'][:position]].blank?
              usable_record[:packing_instructions_conf] = true if ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['packing_instructions_conf'][:position]])
            end

            if !mapping['product_instructions'].nil? && mapping['product_instructions'][:position] >= 0 && !single_row[mapping['product_instructions'][:position]].blank?
              usable_record[:packing_instructions] = single_row[mapping['product_instructions'][:position]]
            end

            if !mapping['receiving_instructions'].nil? && mapping['receiving_instructions'][:position] >= 0 && !single_row[mapping['receiving_instructions'][:position]].blank?
              usable_record[:product_receiving_instructions] = single_row[mapping['receiving_instructions'][:position]]
            end

            if !mapping['remove_sku'].nil? && mapping['remove_sku'][:position] >= 0 && !single_row[mapping['remove_sku'][:position]].blank?
              usable_record[:remove_sku] = single_row[mapping['remove_sku'][:position]]
            end

            if !mapping['avg_cost'].nil? && mapping['avg_cost'][:position] >= 0 && !single_row[mapping['avg_cost'][:position]].blank?
              usable_record[:avg_cost] = single_row[mapping['avg_cost'][:position]].to_f
            end

            if !mapping['count_group'].nil? && mapping['count_group'][:position] >= 0 && !single_row[mapping['count_group'][:position]].blank?
              usable_record[:count_group] = single_row[mapping['count_group'][:position]].chars.first
            end

            if !mapping['restock_lead_time'].nil? && mapping['restock_lead_time'][:position] >= 0 && !single_row[mapping['restock_lead_time'][:position]].blank?
              usable_record[:restock_lead_time] = single_row[mapping['restock_lead_time'][:position]].to_i
            end

            additional_skus = %i[fnsku asin fba_upc isbn ean supplier_sku]
            additional_skus.each do |add_sku|
              if !mapping[add_sku.to_s].nil? && mapping[add_sku.to_s][:position] >= 0 && !single_row[mapping[add_sku.to_s][:position]].blank?
                usable_record[add_sku] = single_row[mapping[add_sku.to_s][:position]]
              end
            end

            usable_record[:all_barcodes] = {}
            usable_record[:all_barcodes_qty] = {}
            if !mapping['barcode'].nil? && mapping['barcode'][:position] >= 0
              unless single_row[mapping['barcode'][:position]].nil?
                barcodes = single_row[mapping['barcode'][:position]].split(',')
                barcode_qty = begin
                                single_row[mapping['barcode_qty'][:position]].split(',')
                              rescue StandardError
                                1
                              end
                usable_record[:all_barcodes]['0'] = barcodes
                barcodes.each do |single_barcode|
                  usable_record[:all_barcodes_qty][single_barcode] = barcode_qty
                  break unless (ProductBarcode.where(barcode: single_barcode.strip).empty? && (!@all_barcodes.include? single_barcode.strip)) || params['permit_duplicate_barcodes']

                  @all_barcodes << single_barcode.strip
                  usable_record[:barcodes] << single_barcode.strip
                end
              end
            elsif params[:generate_barcode_from_sku]
              barcodes = single_row[mapping['sku'][:position]].split(',')
              barcode_qty = begin
                              single_row[mapping['barcode_qty'][:position]].split(',')
                            rescue StandardError
                              1
                            end
              usable_record[:all_barcodes]['0'] = barcodes
              barcodes.each do |single_barcode|
                usable_record[:all_barcodes_qty][single_barcode] = barcode_qty
                @all_barcodes << single_barcode.strip
                usable_record[:barcodes] << single_barcode.strip
              end
            end
            if !mapping['secondary_barcode'].nil? && mapping['secondary_barcode'][:position] >= 0
              unless single_row[mapping['secondary_barcode'][:position]].nil?
                secondary_barcodes = single_row[mapping['secondary_barcode'][:position]].split(',')
                secondary_barcodes_qty = begin
                                           single_row[mapping['secondary_barcode_qty'][:position]].split(',')
                                         rescue StandardError
                                           1
                                         end
                usable_record[:all_barcodes]['1'] = secondary_barcodes
                secondary_barcodes.each do |single_secondary_barcode|
                  usable_record[:all_barcodes_qty][single_secondary_barcode] = secondary_barcodes_qty
                  break unless ProductBarcode.where(barcode: single_secondary_barcode.strip).empty? && (!@all_barcodes.include? single_secondary_barcode.strip)

                  @all_barcodes << single_secondary_barcode.strip
                  usable_record[:barcodes] << single_secondary_barcode.strip
                end
              end
            end

            if !mapping['tertiary_barcode'].nil? && mapping['tertiary_barcode'][:position] >= 0
              unless single_row[mapping['tertiary_barcode'][:position]].nil?
                tertiary_barcodes = single_row[mapping['tertiary_barcode'][:position]].split(',')
                tertiary_barcodes_qty = begin
                                          single_row[mapping['tertiary_barcode_qty'][:position]].split(',')
                                        rescue StandardError
                                          1
                                        end
                usable_record[:all_barcodes]['2'] = tertiary_barcodes
                tertiary_barcodes.each do |single_tertiary_barcode|
                  usable_record[:all_barcodes_qty][single_tertiary_barcode] = tertiary_barcodes_qty
                  break unless ProductBarcode.where(barcode: single_tertiary_barcode.strip).empty? && (!@all_barcodes.include? single_tertiary_barcode.strip)

                  @all_barcodes << single_tertiary_barcode.strip
                  usable_record[:barcodes] << single_tertiary_barcode.strip
                end
              end
            end

            usable_record[:product_record_serial] = true if mapping['product_record_serial'] && ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['product_record_serial'][:position]])
            usable_record[:product_second_record_serial] = true if mapping['product_second_record_serial'] && ['ON', 'on', 'TRUE', true, 'true', 'YES', 'yes', '1'].include?(single_row[mapping['product_second_record_serial'][:position]])

            usable_record[:barcodes] = map_barcodes('quaternary_barcode', '4', single_row, usable_record)
            usable_record[:barcodes] = map_barcodes('quinary_barcode', '5', single_row, usable_record)
            usable_record[:barcodes] = map_barcodes('senary_barcode', '6', single_row, usable_record)

            if !mapping['product_type'].nil? && mapping['product_type'][:position] >= 0
              usable_record[:product_type] = single_row[mapping['product_type'][:position]]
            end
            # add inventory warehouses
            product_inventory = init_prod_inv

            usable_record[:inventory] << build_prod_inv(product_inventory, single_row)

            # add product categories
            if !mapping['category_name'].nil? && mapping['category_name'][:position] >= 0
              unless single_row[mapping['category_name'][:position]].nil?
                usable_record[:cats] = single_row[mapping['category_name'][:position]].split(',')
              end
            end

            if !mapping['product_images'].nil? && mapping['product_images'][:position] >= 0
              unless single_row[mapping['product_images'][:position]].nil?
                usable_record[:images] = single_row[mapping['product_images'][:position]].split(',')
              end
            end
            usable_record
          end

          def build_prod_inv(product_inventory, single_row)
            if !mapping['inv_wh1'].nil? && mapping['inv_wh1'][:position] >= 0
              product_inventory[:quantity_on_hand] = single_row[mapping['inv_wh1'][:position]] || ''
            end
            # if !self.mapping['location_primary'].nil? && self.mapping['location_primary'][:position] >= 0
            #   product_inventory[:location_primary] = single_row[self.mapping['location_primary'][:position]] || ''
            # end
            # if !self.mapping['location_secondary'].nil? && self.mapping['location_secondary'][:position] >= 0
            #   product_inventory[:location_secondary] = single_row[self.mapping['location_secondary'][:position]] || ''
            # end
            # if !self.mapping['location_tertiary'].nil? && self.mapping['location_tertiary'][:position] >= 0
            #   product_inventory[:location_tertiary] = single_row[self.mapping['location_tertiary'][:position]] || ''
            # end
            product_inv_locations = %i[location_primary location_secondary location_tertiary location_quaternary]
            product_inv_locations.each do |location|
              if !mapping[location.to_s].nil? && mapping[location.to_s][:position] >= 0
                product_inventory[location] = single_row[mapping[location.to_s][:position]] || ''
              end
            end

            product_inv_locations_qty = %i[location_primary_qty location_secondary_qty location_tertiary_qty location_quaternary_qty]
            product_inv_locations_qty.each do |location_qty|
              if !mapping[location_qty.to_s].nil? && mapping[location_qty.to_s][:position] >= 0
                product_inventory[location_qty] = single_row[mapping[location_qty.to_s][:position]].to_i
              end
            end

            alert_levels = %i[product_inv_alert_level product_inv_target_level]
            alert_levels.each do |alert_level|
              if !mapping[alert_level.to_s].nil? && mapping[alert_level.to_s][:position] >= 0
                product_inventory[alert_level] = single_row[mapping[alert_level.to_s][:position]].to_i
              end
            end

            product_inventory
          end

          def find_product(record)
            if record[:remove_sku].present?
              sku = ProductSku.find_by_sku(record[:remove_sku])
              @product = Product.find_by_id(sku.try(:product_id))
              return @product if @product
            end

            record[:skus].each do |sku|
              if sku != '[DELETE]'
                sku = ProductSku.find_by_sku(sku)
                @product = Product.find_by_id(sku.try(:product_id))
              end
            end
            @product
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

          def check_after_every(length)
            return 5 if length <= 1000
            return 25 if length <= 5000
            return 50 if length <= 10_000

            100
          end

          def delete_existing_images(images)
            images.each(&:destroy)
          end

          def collect_related_data_for_new_prod(found_products)
            @to_import_records.each_with_index do |record, index|
              product_id = found_products[record[:store_product_id]]
              if product_id > 0
                unless record[:skus].empty?
                  new_order = 0
                  record[:skus].each do |sku|
                    next unless sku != '[DELETE]'

                    begin
                      product_sku = ProductSku.new
                      product_sku.sku = sku
                      product_sku.order = new_order
                      product_sku.product_id = product_id
                      product_sku.save!
                      # @import_product_skus << product_sku
                      new_order += 1
                    rescue Exception => e
                      Rollbar.error(e, e.message, Apartment::Tenant.current)
                    end
                  end
                end

                unless record[:barcodes].empty?
                  new_order = 0
                  record[:barcodes].each do |barcode|
                    next unless barcode != '[DELETE]'

                    next unless params['permit_duplicate_barcodes'] || !(@found_barcodes.include? barcode)

                    begin
                      product_barcode = ProductBarcode.new
                      product_barcode.barcode = barcode
                      product_barcode.packing_count = begin
                                                          record[:all_barcodes_qty][barcode][0]
                                                      rescue StandardError
                                                        1
                                                        end
                      product_barcode.is_multipack_barcode = true
                      product_barcode.order = new_order
                      product_barcode.product_id = product_id
                      product_barcode.permit_shared_barcodes = params['permit_duplicate_barcodes']
                      product_barcode.save
                      # @import_product_barcodes << product_barcode
                      new_order += 1
                    rescue Exception => e
                      Rollbar.error(e, e.message, Apartment::Tenant.current)
                    end
                  end
                end

                unless record[:images].empty?
                  new_order = 0
                  record[:images].each do |image|
                    next unless image != '[DELETE]'

                    new_order += 1
                    product_image = ProductImage.new
                    product_image.image = image
                    product_image.order = new_order
                    product_image.product_id = product_id
                    @import_product_images << product_image
                  end
                end

                unless record[:cats].empty?
                  record[:cats].each do |cat|
                    next unless cat != '[DELETE]'

                    product_cat = ProductCat.new
                    product_cat.category = cat
                    product_cat.product_id = product_id
                    @import_product_cats << product_cat
                  end
                end

                unless record[:inventory].empty?
                  record[:inventory].each do |warehouse|
                    next unless warehouse != '[DELETE]'

                    product_inv_wh = ProductInventoryWarehouses.new
                    product_inv_wh.inventory_warehouse_id = warehouse[:inventory_warehouse_id]
                    product_inv_wh.location_primary = warehouse[:location_primary] if warehouse[:location_primary] != '[DELETE]'
                    product_inv_wh.location_secondary = warehouse[:location_secondary] if warehouse[:location_secondary] != '[DELETE]'
                    product_inv_wh.location_tertiary = warehouse[:location_tertiary] if warehouse[:location_tertiary] != '[DELETE]'
                    product_inv_wh.location_quaternary = warehouse[:location_quaternary] if warehouse[:location_quaternary] != '[DELETE]'
                    product_inv_wh.location_primary_qty = warehouse[:location_primary_qty] if warehouse[:location_primary_qty] != '[DELETE]'
                    product_inv_wh.location_secondary_qty = warehouse[:location_secondary_qty] if warehouse[:location_secondary_qty] != '[DELETE]'
                    product_inv_wh.location_tertiary_qty = warehouse[:location_tertiary_qty] if warehouse[:location_tertiary_qty] != '[DELETE]'
                    product_inv_wh.location_quaternary_qty = warehouse[:location_quaternary_qty] if warehouse[:location_quaternary_qty] != '[DELETE]'
                    product_inv_wh.quantity_on_hand = warehouse[:quantity_on_hand] if warehouse[:quantity_on_hand] != '[DELETE]'
                    product_inv_wh.product_inv_alert_level = warehouse[:product_inv_alert_level] if warehouse[:product_inv_alert_level] != '[DELETE]'
                    product_inv_wh.product_inv_target_level = warehouse[:product_inv_target_level] if warehouse[:product_inv_target_level] != '[DELETE]'

                    product_inv_wh.product_id = product_id
                    @import_product_inventory_warehouses << product_inv_wh
                  end
                end
              end
              @success += 1
              next unless (index + 1) % @check_length === 0 || index === (@to_import_records.length - 1)

              @product_import.success = @success
              @product_import.current_sku = record[:skus].last
              @product_import.status = 'importing_skus' if index === (@to_import_records.length - 1)
              @product_import.save
            end
          end

          def overwrite_existing_product(record)
            product = find_product(record)
            delete_product(record)
            record[:images].each_with_index do |image, new_order|
              product.product_images.find_by_order(new_order).destroy if image == '[DELETE]'
            rescue StandardError
              nil
            end
            (product.try(:product_images) || []).each do |image, index|
              image.order = index
              image.save
            end
            product.update_attribute(:name, 'Product created from CSV import') if record[:name] == '[DELETE]'
            pro_barcodes = product.try(:product_barcodes)
            barcodes = record[:all_barcodes]

            unless record[:barcodes].empty?
              record[:barcodes].each do |barcode|
                next unless barcode != '[DELETE]'

                begin
                  product_barcode = ProductBarcode.new
                  product_barcode.barcode = barcode
                  product_barcode.packing_count = begin
                                                      record[:all_barcodes_qty][barcode][0]
                                                  rescue StandardError
                                                    1
                                                    end
                  product_barcode.is_multipack_barcode = true
                  product_barcode.product_id = begin
                                                   product.id
                                               rescue StandardError
                                                 nil
                                                 end
                  product_barcode.save
                rescue Exception => e
                  Rollbar.error(e, e.message, Apartment::Tenant.current)
                end
              end
            end

            (pro_barcodes || []).each_with_index do |_barcode, index|
              pro_barcodes.where(order: index)[0].destroy if barcodes[index.to_s][0] == '[DELETE]'
            rescue StandardError
              nil
            end
            (product.try(:product_barcodes) || []).each_with_index do |barcode, index|
              barcode.update_attribute(:order, index)
            end
            record[:cats].each_with_index do |cat, index|
              product.product_cats[index].destroy if cat == '[DELETE]'
            rescue StandardError
              nil
            end
            product.update_attribute(:packing_instructions, nil) if record[:packing_instructions] == '[DELETE]'
            product.update_attribute(:product_receiving_instructions, nil) if record[:product_receiving_instructions] == '[DELETE]'
            product.update_attribute(:weight, nil) if record[:weight] == '[DELETE]'
            record[:inventory].each_with_index do |inventory, index|
              product_inv = product.product_inventory_warehousess[index]
              product_inv.update_attribute(:location_primary, nil) if inventory[:location_primary] == '[DELETE]'
              product_inv.update_attribute(:location_secondary, nil) if inventory[:location_secondary] == '[DELETE]'
              product_inv.update_attribute(:location_tertiary, nil) if inventory[:location_tertiary] == '[DELETE]'
              product_inv.update_attribute(:location_quaternary, nil) if inventory[:location_quaternary] == '[DELETE]'
              product_inv.update_attribute(:location_primary_qty, nil) if inventory[:location_primary_qty] == '[DELETE]'
              product_inv.update_attribute(:location_secondary_qty, nil) if inventory[:location_secondary_qty] == '[DELETE]'
              product_inv.update_attribute(:location_tertiary_qty, nil) if inventory[:location_tertiary_qty] == '[DELETE]'
              product_inv.update_attribute(:location_quaternary_qty, nil) if inventory[:location_quaternary_qty] == '[DELETE]'
              product_inv.update_attribute(:quantity_on_hand, nil) if inventory[:quantity_on_hand] == '[DELETE]'
            rescue StandardError
            end
          end

          def apply_intangible(usable_record)
            scan_pack_settings = ScanPackSetting.all.first
            if scan_pack_settings.intangible_setting_enabled
              unless scan_pack_settings.intangible_string.nil? || (scan_pack_settings.intangible_string.strip.equal? '')
                intangible_strings = scan_pack_settings.intangible_string.strip.split(',')
                intangible_strings.each do |string|
                  return true if usable_record[:name].include? string

                  usable_record[:skus].each do |sku|
                    return true if sku.include? string
                  end
                end
              end
            end
            false
          end
        end
      end
    end
  end
end
