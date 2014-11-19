module Groovepacker
  module Store
    module Importers
      module CSV
        class ProductsImporter
          def import(params,final_record,mapping)
            result = Hash.new
            result['status'] = true
            result['messages'] = []
            check_length = check_after_every(final_record.length)
            success = 0
            duplicate_action = 'skip'
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
            default_inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id

            final_record.each_with_index do |single_row,index|
              if !mapping['sku'].nil? && mapping['sku'] >= 0 && !single_row[mapping['sku']].blank?
                usable_record = {}
                usable_record[:name] = ''
                usable_record[:skus] = []
                usable_record[:barcodes] = []
                usable_record[:store_product_id] = store_product_id_base+index.to_s
                usable_record[:cats] = []
                usable_record[:images] = []
                usable_record[:inventory] = []
                usable_record[:product_type] = ''

                if !mapping['product_name'].nil? && mapping['product_name'] >= 0 && !single_row[mapping['product_name']].blank?
                  usable_record[:name] = single_row[mapping['product_name']]
                end
                if usable_record[:name].blank?
                  usable_record[:name] = 'Product from CSV Import'
                end
                prim_skus = single_row[mapping['sku']].split(',')
                prim_skus.each do |prim_single_sku|
                  all_skus << prim_single_sku
                  usable_record[:skus] << prim_single_sku
                end
                if !mapping['secondary_sku'].nil? && mapping['secondary_sku'] >= 0
                  unless single_row[mapping['secondary_sku']].nil?
                    sec_skus = single_row[mapping['secondary_sku']].split(',')
                    sec_skus.each do |sec_single_sku|
                      unless usable_record[:skus].include? sec_single_sku
                        all_skus << sec_single_sku
                        usable_record[:skus] << sec_single_sku
                      end
                    end
                  end
                end

                if !mapping['barcode'].nil? && mapping['barcode'] >= 0
                  unless single_row[mapping['barcode']].nil?
                    barcodes = single_row[mapping['barcode']].split(',')
                    barcodes.each do |single_barcode|
                      all_barcodes << single_barcode
                      usable_record[:barcodes] << single_barcode
                    end
                  end
                end

                if !mapping['product_type'].nil? && mapping['product_type'] >= 0
                  usable_record[:product_type] = single_row[mapping['product_type']]
                end
                #add inventory warehouses
                  product_inventory = {}
                  product_inventory[:inventory_warehouse_id] = default_inventory_warehouse_id
                  product_inventory[:available_inv] = 0
                  product_inventory[:location_primary] = ''
                  product_inventory[:location_secondary] = ''
                  product_inventory[:location_tertiary] = ''
                  if !mapping['inv_wh1'].nil? && mapping['inv_wh1'] >= 0
                    product_inventory[:available_inv] = single_row[mapping['inv_wh1']]
                  end
                  if !mapping['location_primary'].nil? && mapping['location_primary'] >= 0
                    product_inventory[:location_primary] = single_row[mapping['location_primary']]
                  end
                  if !mapping['location_secondary'].nil? && mapping['location_secondary'] >= 0
                    product_inventory[:location_secondary] = single_row[mapping['location_secondary']]
                  end
                  if !mapping['location_tertiary'].nil? && mapping['location_tertiary'] >= 0
                    product_inventory[:location_tertiary] = single_row[mapping['location_tertiary']]
                  end
                  usable_record[:inventory] << product_inventory

                #add product categories
                if !mapping['category_name'].nil? && mapping['category_name'] >= 0
                  unless single_row[mapping['category_name']].nil?
                    usable_record[:cats] = single_row[mapping['category_name']].split(',')
                  end
                end

                if !mapping['product_images'].nil? && mapping['product_images'] >= 0
                  unless single_row[mapping['product_images']].nil?
                    usable_record[:images] =  single_row[mapping['product_images']].split(',')
                  end
                end

                usable_records << usable_record

                success = success + 1
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
            usable_records.each_with_index do |record,index|
              duplicate_found =  false
              record[:skus].each do |sku|
                if found_skus.has_key? sku
                  duplicate_found = found_skus[:sku]
                  break
                end
              end

              if duplicate_found === false
                single_import = Product.new(:name=> record[:name],:product_type => record[:product_type])
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
              elsif duplicate_action == 'update'
                #update the product directly
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


            import_product_skus = []
            import_product_images = []
            import_product_barcodes = []
            import_product_cats = []
            import_product_inventory_warehouses = []

            to_import_records.each_with_index do |record,index|
              product_id = found_products[record[:store_product_id]]
              if product_id > 0
                if record[:skus].length > 0
                  record[:skus].each_with_index do |sku,sku_order|
                    product_sku = ProductSku.new
                    product_sku.sku = sku
                    product_sku.order = sku_order
                    product_sku.product_id = product_id
                    import_product_skus << product_sku
                  end
                end

                if record[:barcodes].length > 0
                  record[:barcodes].each_with_index do |barcode,barcode_order|
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
                  record[:images].each_with_index do |image,image_order|
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
                    product_inv_wh.product_id = product_id
                    import_product_inventory_warehouses << product_inv_wh
                  end
                end
              end
              success =  success + 1
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

            Product.where(:store_id => params[:store_id]).update_all(:store_product_id => 0)
            product_import.status = 'completed'
            product_import.save
            result
          end

          def import_old(params,final_record,mapping)
            result = Hash.new
            result['status'] = true
            result['messages'] = []
            product_import = CsvProductImport.find_by_store_id(params[:store_id])
            if product_import.nil?
              product_import = CsvProductImport.new
              product_import.store_id = params[:store_id]
            end
            product_import.status = 'in_progress'
            product_import.success = 0
            product_import.current_sku = ''
            product_import.total = final_record.length
            product_import.save

            #products notification drawer
            final_record.each_with_index do |single_row,index|
              product_import.reload
              if product_import.cancel
                product_import.status = 'cancelled'
                product_import.save
                return true
              end

              if !mapping['sku'].nil? && mapping['sku'] >= 0 && !single_row[mapping['sku']].blank?
                duplicate_found = false
                skus = single_row[mapping['sku']].split(',')
                product_import.current_sku = skus.first
                product_import.save

                skus.each do |single_sku|
                  if ProductSku.where(:sku=>single_sku).length > 0
                    duplicate_found = true
                    break
                  end
                end


                if !duplicate_found
                  #product import code here
                  product = Product.new
                  product.store_id = params[:store_id]
                  product.store_product_id = 0
                  product.name = ''
                  if !mapping['product_name'].nil? && mapping['product_name'] >= 0
                    product.name = single_row[mapping['product_name']]
                  end
                  if product.name.blank?
                    product.name = 'Product from CSV Import'
                  end
                  if !mapping['product_type'].nil? && mapping['product_type'] >= 0
                    product.product_type = single_row[mapping['product_type']]
                  end

                  #add inventory warehouses
                  if !mapping['location_primary'].nil? || !mapping['inv_wh1'].nil? || !mapping['location_secondary'].nil? || !mapping['location_tertiary'].nil?
                    product_inventory = ProductInventoryWarehouses.new
                    product_inventory.inventory_warehouse = InventoryWarehouse.where(:is_default => true).first
                    valid_inventory = false
                    if !mapping['inv_wh1'].nil? && mapping['inv_wh1'] >= 0
                      product_inventory.available_inv = single_row[mapping['inv_wh1']]
                      valid_inventory = true
                    end
                    if !mapping['location_primary'].nil? && mapping['location_primary'] >= 0
                      product_inventory.location_primary = single_row[mapping['location_primary']]
                      valid_inventory = true
                    end
                    if !mapping['location_secondary'].nil? && mapping['location_secondary'] >= 0
                      product_inventory.location_secondary = single_row[mapping['location_secondary']]
                      valid_inventory = true
                    end
                    if !mapping['location_tertiary'].nil? && mapping['location_tertiary'] >= 0
                      product_inventory.location_tertiary = single_row[mapping['location_tertiary']]
                      valid_inventory = true
                    end
                    product.product_inventory_warehousess << product_inventory if valid_inventory
                  end

                  #add product categories
                  if !mapping['category_name'].nil? && mapping['category_name'] >= 0
                    unless single_row[mapping['category_name']].nil?
                      cats = single_row[mapping['category_name']].split(',')
                      cats.each do |single_cat|
                        product_cat = ProductCat.new
                        product_cat.category = single_cat
                        product.product_cats << product_cat
                      end
                    end
                  end

                  if !mapping['product_images'].nil? && mapping['product_images'] >= 0
                    unless single_row[mapping['product_images']].nil?
                      images = single_row[mapping['product_images']].split(',')
                      images.each do |single_image|
                        product_image = ProductImage.new
                        product_image.image = single_image
                        product.product_images << product_image
                      end
                    end
                  end

                  if !mapping['sku'].nil? && mapping['sku'] >= 0
                    unless single_row[mapping['sku']].nil?
                      prim_skus = single_row[mapping['sku']].split(',')
                      prim_skus.each do |prim_single_sku|
                        if ProductSku.where(:sku=>prim_single_sku).length == 0
                          product_sku = ProductSku.new
                          product_sku.sku = prim_single_sku
                          product.product_skus << product_sku
                        end
                      end
                    end
                  end
                  if !mapping['secondary_sku'].nil? && mapping['secondary_sku'] >= 0
                    unless single_row[mapping['secondary_sku']].nil?
                      sec_skus = single_row[mapping['secondary_sku']].split(',')
                      sec_skus.each do |sec_single_sku|
                        if ProductSku.where(:sku=>sec_single_sku).length == 0
                          product_sku = ProductSku.new
                          product_sku.sku = sec_single_sku
                          product.product_skus << product_sku
                        end
                      end
                    end
                  end
                  if !mapping['barcode'].nil? && mapping['barcode'] >= 0
                    unless single_row[mapping['barcode']].nil?
                      barcodes = single_row[mapping['barcode']].split(',')
                      barcodes.each do |single_barcode|
                        if ProductBarcode.where(:barcode => single_barcode).length == 0
                          product_barcode = ProductBarcode.new
                          product_barcode.barcode = single_barcode
                          product.product_barcodes << product_barcode
                        end
                      end
                    end
                  end
                  if result["status"]
                    begin
                      if product.name != 'name' && !product.name.empty?
                        product.save!
                        product.update_product_status
                      end
                    rescue ActiveRecord::RecordInvalid => e
                      result['status'] = false
                      result['messages'].push(product.errors.full_messages)
                    rescue ActiveRecord::StatementInvalid => e
                      result['status'] = false
                      result['messages'].push(e.message)
                    rescue Exception => e
                      result['status'] = false
                      result['messages'].push(e.message)
                    end
                  end
                else
                  #result previous imported + 1
                end
              else
                #Skipped because of no SKU
              end
              product_import.success = product_import.success + 1
              product_import.save
              unless result['status']
                product_import.status = 'failed'
                product_import.message = 'Import halted because of errors, the last imported row was '+index.to_s
                product_import.save
                break
              end
            end
            if result['status']
              product_import.status = 'completed'
              product_import.save
            end
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
