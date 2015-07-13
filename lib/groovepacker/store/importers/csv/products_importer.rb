module Groovepacker
	module Store
		module Importers
			module CSV
				class ProductsImporter
					def import(params, final_record, mapping, import_action)
						result = Hash.new
						result['status'] = true
						result['messages'] = []
						check_length = check_after_every(final_record.length)
						success = 0
						success_imported = 0
						success_updated = 0
						duplicate_file = 0
						duplicate_db = 0
						duplicate_action = 'skip'
						new_action = 'skip'
						unless import_action.nil?
							if ['update_existing', 'create_update'].include?(import_action)
								duplicate_action = 'overwrite'
							end

							if ['create_new', 'create_update'].include?(import_action)
								new_action = 'create'
							end
						end
						product_import = CsvProductImport.find_by_store_id(params[:store_id])
						if product_import.nil?
							product_import = CsvProductImport.new
							product_import.store_id = params[:store_id]
						end
						store_product_id_base = 'csv_import_'+params[:store_id].to_s+'_'+SecureRandom.uuid+'_'
						product_import.status = 'processing_csv'
						product_import.success = success
						product_import.current_sku = ''
						product_import.total = final_record.length
						product_import.save
						all_skus = []
						all_barcodes = []
						usable_records = []
						products_for_status_update = []
						default_inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id

						final_record.each_with_index do |single_row, index|
							single_row_skus = []
							if !mapping['sku'].nil? && mapping['sku'][:position] >= 0 && !single_row[mapping['sku'][:position]].blank?

								prim_skus = single_row[mapping['sku'][:position]].split(',')
								prim_skus.each do |prim_single_sku|
									single_row_skus << prim_single_sku
								end
								if !mapping['secondary_sku'].nil? && mapping['secondary_sku'][:position] >= 0
									unless single_row[mapping['secondary_sku'][:position]].nil?
										sec_skus = single_row[mapping['secondary_sku'][:position]].split(',')
										sec_skus.each do |sec_single_sku|
											unless single_row_skus.include? sec_single_sku
												single_row_skus << sec_single_sku
											end
										end
									end
								end
								if !mapping['tertiary_sku'].nil? && mapping['tertiary_sku'][:position] >= 0
									unless single_row[mapping['tertiary_sku'][:position]].nil?
										tert_skus = single_row[mapping['tertiary_sku'][:position]].split(',')
										tert_skus.each do |tert_single_sku|
											unless single_row_skus.include? tert_single_sku
												single_row_skus << tert_single_sku
											end
										end
									end
								end

								if (all_skus & single_row_skus).length > 0
									duplicate_file = duplicate_file + 1
									#duplicate_skus << (all_skus & single_row_skus)
								else
									usable_record = {}
									usable_record[:name] = ''
									usable_record[:skus] = []
									usable_record[:barcodes] = []
									usable_record[:store_product_id] = store_product_id_base+index.to_s
									usable_record[:cats] = []
									usable_record[:images] = []
									usable_record[:inventory] = []
									usable_record[:product_type] = ''
									usable_record[:spl_instructions_4_packer] = ''

									all_skus = all_skus + single_row_skus
									usable_record[:skus] = single_row_skus

									if !mapping['product_name'].nil? && mapping['product_name'][:position] >= 0 && !single_row[mapping['product_name'][:position]].blank?
										usable_record[:name] = single_row[mapping['product_name'][:position]]
									end
									if params[:use_sku_as_product_name]
										usable_record[:name] = single_row[mapping['sku'][:position]]
									end
									if usable_record[:name].blank?
										usable_record[:name] = 'Product from CSV Import'
									end

									if !mapping['product_instructions'].nil? && mapping['product_instructions'][:position] >= 0 && !single_row[mapping['product_instructions'][:position]].blank?
										usable_record[:spl_instructions_4_packer] = single_row[mapping['product_instructions'][:position]]
									end


									if !mapping['barcode'].nil? && mapping['barcode'][:position] >= 0
										unless single_row[mapping['barcode'][:position]].nil?
											barcodes = single_row[mapping['barcode'][:position]].split(',')
											barcodes.each do |single_barcode|
												all_barcodes << single_barcode
												usable_record[:barcodes] << single_barcode
											end
										end
									elsif params[:generate_barcode_from_sku]
										barcodes = single_row[mapping['sku'][:position]].split(',')
										barcodes.each do |single_barcode|
											all_barcodes << single_barcode
											usable_record[:barcodes] << single_barcode
										end
									end

									if !mapping['secondary_barcode'].nil? && mapping['secondary_barcode'][:position] >= 0
										unless single_row[mapping['secondary_barcode'][:position]].nil?
											secondary_barcodes = single_row[mapping['secondary_barcode'][:position]].split(',')
											secondary_barcodes.each do |single_secondary_barcode|
												all_barcodes << single_secondary_barcode
												usable_record[:barcodes] << single_secondary_barcode
											end
										end
									end

									if !mapping['tertiary_barcode'].nil? && mapping['tertiary_barcode'][:position] >= 0
										unless single_row[mapping['tertiary_barcode'][:position]].nil?
											tertiary_barcodes = single_row[mapping['tertiary_barcode'][:position]].split(',')
											tertiary_barcodes.each do |single_tertiary_barcode|
												all_barcodes << single_tertiary_barcode
												usable_record[:barcodes] << single_tertiary_barcode
											end
										end
									end

									if !mapping['product_type'].nil? && mapping['product_type'][:position] >= 0
										usable_record[:product_type] = single_row[mapping['product_type'][:position]]
									end
									#add inventory warehouses
									product_inventory = {}
									product_inventory[:inventory_warehouse_id] = default_inventory_warehouse_id
									product_inventory[:quantity_on_hand] = 0
									product_inventory[:location_primary] = ''
									product_inventory[:location_secondary] = ''
									product_inventory[:location_tertiary] = ''
									if !mapping['inv_wh1'].nil? && mapping['inv_wh1'][:position] >= 0
										product_inventory[:quantity_on_hand] = single_row[mapping['inv_wh1'][:position]]
									end
									if !mapping['location_primary'].nil? && mapping['location_primary'][:position] >= 0
										product_inventory[:location_primary] = single_row[mapping['location_primary'][:position]]
									end
									if !mapping['location_secondary'].nil? && mapping['location_secondary'][:position] >= 0
										product_inventory[:location_secondary] = single_row[mapping['location_secondary'][:position]]
									end
									if !mapping['location_tertiary'].nil? && mapping['location_tertiary'][:position] >= 0
										product_inventory[:location_tertiary] = single_row[mapping['location_tertiary'][:position]]
									end
									usable_record[:inventory] << product_inventory

									#add product categories
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

									usable_records << usable_record

									success = success + 1
								end


							end

							if (index + 1) % check_length === 0 || index === (final_record.length - 1)
								product_import.reload
								product_import.success = success
								product_import.current_sku = all_skus.last
								if product_import.cancel
									product_import.status = 'cancelled'
									product_import.save
									return true
								end
								if index === (final_record.length - 1)
									success = 0
									product_import.status = 'processing_products'
									product_import.success = success
									product_import.current_sku = ''
									product_import.total = usable_records.length
								end
								product_import.save
							end
						end
						final_record.clear

						found_skus_raw = ProductSku.find_all_by_sku(all_skus)
						found_skus = {}
						found_barcodes_raw = ProductBarcode.find_all_by_barcode(all_barcodes)
						found_barcodes = []
						found_skus_raw.each do |found_sku|
							found_skus[found_sku.sku] = found_sku
							if duplicate_action !='overwrite'
								duplicate_db = duplicate_db + 1
							end
						end
						found_barcodes_raw.each do |found_barcode|
							found_barcodes << found_barcode.barcode
						end
						found_skus_raw = nil
						found_barcodes_raw = nil
						all_skus.clear
						all_barcodes.clear

						products_to_import = []

						to_import_records = []
						all_unique_ids = []

						import_product_skus = []
						import_product_images = []
						import_product_barcodes = []
						import_product_cats = []
						import_product_inventory_warehouses = []

						usable_records.each_with_index do |record, index|
							duplicate_found = false
							record[:skus].each do |sku|
								if found_skus.has_key? sku
									duplicate_found = sku
									break
								end
							end

							if duplicate_found === false && new_action == 'create'
								single_import = Product.new(:name => record[:name], :product_type => record[:product_type], :spl_instructions_4_packer => record[:spl_instructions_4_packer])
								single_import.store_id = params[:store_id]
								single_import.store_product_id = record[:store_product_id]
								if record[:skus].length > 0 && record[:barcodes].length > 0
									single_import.status = 'active'
								else
									single_import.status = 'new'
								end

								to_import_records << record
								all_unique_ids << record[:store_product_id]


								products_to_import << single_import
							elsif duplicate_action == 'overwrite'
								#update the product directly
								single_product_duplicate_sku = ProductSku.find_by_sku(duplicate_found)
								duplicate_product = Product.find_by_id(single_product_duplicate_sku.product_id)
								duplicate_product.store_id = params[:store_id]
								if !mapping['product_name'].nil? #&& mapping['product_name'][:action] == 'overwrite'
									duplicate_product.name = record[:name]
								end
								if !mapping['product_type'].nil? #&& mapping['product_type'][:action] == 'overwrite'
									duplicate_product.product_type = record[:product_type]
								end
								if !mapping['product_instructions'].nil? #&& mapping['product_instructions'][:action] == 'overwrite'
									duplicate_product.spl_instructions_4_packer = record[:spl_instructions_4_packer]
								end
								if record[:skus].length > 0 && record[:barcodes].length > 0
									duplicate_product.status = 'active'
								else
									products_for_status_update << duplicate_product
								end
								duplicate_product.save
								success_updated = success_updated + 1

								if (!mapping['inv_wh1'].nil? || !mapping['location_primary'].nil? || !mapping['location_secondary'].nil? || !mapping['location_tertiary'].nil?)
									default_inventory = ProductInventoryWarehouses.find_or_create_by_inventory_warehouse_id_and_product_id(default_inventory_warehouse_id, duplicate_product.id)
									updatable_record = record[:inventory].first
									if !mapping['inv_wh1'].nil? #&& mapping['inv_wh1'][:action] =='overwrite'
										default_inventory.quantity_on_hand = updatable_record[:quantity_on_hand]
									end
									if !mapping['location_primary'].nil? #&& mapping['location_primary'][:action] =='overwrite'
										default_inventory.location_primary = updatable_record[:location_primary]
									end
									if !mapping['location_secondary'].nil? #&& mapping['location_secondary'][:action] =='overwrite'
										default_inventory.location_secondary = updatable_record[:location_secondary]
									end
									if !mapping['location_tertiary'].nil? #&& mapping['location_tertiary'][:action] =='overwrite'
										default_inventory.location_tertiary = updatable_record[:location_tertiary]
									end
									default_inventory.save
								end


								if !mapping['category_name'].nil? && record[:cats].length > 0
									#if mapping['category_name'][:action] == 'overwrite'
									#  ProductCat.where(product_id: duplicate_product.id).delete_all
									#end

									#if mapping['category_name'][:action] == 'add' || mapping['category_name'][:action] == 'overwrite'
									all_found_cats = ProductCat.where(product_id: duplicate_product.id)
									to_not_add_cats = []
									all_found_cats.each do |single_found_dup_cat|
										unless record[:cats].include? single_found_dup_cat.category
											to_not_add_cats << single_found_dup_cat.category
										end
									end
									record[:cats].each do |single_to_add_cat|
										unless to_not_add_cats.include?(single_to_add_cat)
											to_add_cat = ProductCat.new
											to_add_cat.category = single_to_add_cat
											to_add_cat.product_id = duplicate_product.id
											import_product_cats << to_add_cat
										end
									end
									#end
								end
								if !mapping['barcode'].nil? && record[:barcodes].length > 0
									#if mapping['barcode'][:action] == 'overwrite'
									#  ProductBarcode.where(product_id: duplicate_product.id).delete_all
									#end
									#if mapping['barcode'][:action] == 'add' || mapping['barcode'][:action] == 'overwrite'
									all_found_barcodes = ProductBarcode.where(product_id: duplicate_product.id)
									to_not_add_barcodes = []
									all_found_barcodes.each do |single_found_dup_barcode|
										unless record[:barcodes].include? single_found_dup_barcode.barcode
											to_not_add_barcodes << single_found_dup_barcode.barcode
										end
									end
									record[:barcodes].each_with_index do |single_to_add_barcode, index|
										unless to_not_add_barcodes.include?(single_to_add_barcode)
											to_add_barcode = ProductBarcode.new
											to_add_barcode.barcode = single_to_add_barcode
											to_add_barcode.order = index
											to_add_barcode.product_id = duplicate_product.id
											import_product_barcodes << to_add_barcode
										end
									end
									#end
								end

								if !mapping['sku'].nil? && record[:skus].length > 0
									#if mapping['sku'][:action] == 'overwrite'
									#  ProductSku.where(product_id: duplicate_product.id).delete_all
									#end
									#if mapping['sku'][:action] == 'add' || mapping['sku'][:action] == 'overwrite'
									all_found_skus = ProductSku.where(product_id: duplicate_product.id)
									to_not_add_skus = []
									all_found_skus.each do |single_found_dup_sku|
										unless record[:skus].include? single_found_dup_sku.sku
											to_not_add_skus << single_found_dup_sku.sku
										end
									end
									record[:skus].each_with_index do |single_to_add_sku, index|
										unless to_not_add_skus.include?(single_to_add_sku)
											to_add_sku = ProductSku.new
											to_add_sku.sku = single_to_add_sku
											to_add_sku.order = index
											to_add_sku.product_id = duplicate_product.id
											import_product_skus << to_add_sku
										end
									end
									#end
								end

								if !mapping['product_images'].nil? && record[:images].length > 0
									#if mapping['product_images'][:action] == 'overwrite'
									#  ProductImage.where(product_id: duplicate_product.id).delete_all
									#end
									#if mapping['product_images'][:action] == 'add' || mapping['product_images'][:action] == 'overwrite'
									all_found_images = ProductImage.where(product_id: duplicate_product.id)
									to_not_add_images = []
									all_found_images.each do |single_found_dup_image|
										unless record[:images].include? single_found_dup_image.image
											to_not_add_images << single_found_dup_image.image
										end
									end
									record[:images].each_with_index do |single_to_add_image, index|
										unless to_not_add_images.include?(single_to_add_image)
											to_add_image = ProductImage.new
											to_add_image.image = single_to_add_image
											to_add_image.order = index
											to_add_image.product_id = duplicate_product.id
											import_product_images << to_add_image
										end
									end
									#end
								end

							end
							success = success + 1
							if (index + 1) % check_length === 0 || index === (usable_records.length - 1)
								product_import.reload
								product_import.success = success
								product_import.current_sku = record[:skus].last
								if product_import.cancel
									product_import.status = 'cancelled'
									product_import.save
									return true
								end
								if index === (usable_records.length - 1)
									product_import.status = 'importing_products'
								end
								product_import.save
							end
						end
						success_imported = products_to_import.length

						usable_records.clear
						found_skus = nil
						Product.import products_to_import
						found_products_raw = Product.find_all_by_store_product_id(all_unique_ids)

						found_products = {}

						found_products_raw.each do |product|
							found_products[product.store_product_id] = product.id
						end

						found_products_raw = nil
						all_unique_ids.clear

						success = 0
						product_import.status = 'processing_rest'
						product_import.success = success
						product_import.current_sku = ''
						product_import.total = to_import_records.length
						product_import.save

						to_import_records.each_with_index do |record, index|
							product_id = found_products[record[:store_product_id]]
							if product_id > 0
								if record[:skus].length > 0
									record[:skus].each_with_index do |sku, sku_order|
										product_sku = ProductSku.new
										product_sku.sku = sku
										product_sku.order = sku_order
										product_sku.product_id = product_id
										import_product_skus << product_sku
									end
								end

								if record[:barcodes].length > 0
									record[:barcodes].each_with_index do |barcode, barcode_order|
										unless found_barcodes.include? barcode
											product_barcode = ProductBarcode.new
											product_barcode.barcode = barcode
											product_barcode.order = barcode_order
											product_barcode.product_id = product_id
											import_product_barcodes << product_barcode
										end
									end
								end

								if record[:images].length > 0
									record[:images].each_with_index do |image, image_order|
										product_image = ProductImage.new
										product_image.image = image
										product_image.order = image_order
										product_image.product_id = product_id
										import_product_images << product_image
									end
								end

								if record[:cats].length > 0
									record[:cats].each do |cat|
										product_cat = ProductCat.new
										product_cat.category = cat
										product_cat.product_id = product_id
										import_product_cats << product_cat
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
										import_product_inventory_warehouses << product_inv_wh
									end
								end
							end
							success = success + 1
							if (index + 1) % check_length === 0 || index === (to_import_records.length - 1)
								product_import.success = success
								product_import.current_sku = record[:skus].last
								if index === (to_import_records.length - 1)
									product_import.status = 'importing_skus'
								end
								product_import.save
							end
						end
						to_import_records.clear
						found_products = nil
						found_barcodes.clear

						ProductSku.import import_product_skus

						import_product_skus.clear
						product_import.status = 'importing_barcodes'
						product_import.save

						ProductBarcode.import import_product_barcodes

						import_product_barcodes.clear
						product_import.status = 'importing_cats'
						product_import.save

						ProductCat.import import_product_cats

						import_product_cats.clear
						product_import.status = 'importing_images'
						product_import.save

						ProductImage.import import_product_images

						import_product_images.clear
						product_import.status = 'importing_inventory'
						product_import.save

						ProductInventoryWarehouses.import import_product_inventory_warehouses


						import_product_inventory_warehouses.clear


						product_import.status = 'processing_status'
						product_import.save
						products_for_status_update.each do |status_update_product|
							status_update_product.reload
							status_update_product.update_product_status
						end


						Product.where(:store_id => params[:store_id]).update_all(:store_product_id => 0)
						product_import.success_imported = success_imported
						product_import.success_updated = success_updated
						product_import.duplicate_file = duplicate_file
						product_import.duplicate_db = duplicate_db
						product_import.status = 'completed'
						product_import.save
						result
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

				end
			end
		end
	end
end
