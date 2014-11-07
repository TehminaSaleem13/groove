class ImportCsv
  def import(tenant,params)
    Apartment::Tenant.switch(tenant)
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    result['last_row'] = 0
    csv_directory = 'uploads/csv'
    file_path = File.join(csv_directory, "#{tenant}.#{params[:store_id]}.#{params[:type]}.csv")
    if File.exists? file_path
      final_record = []
      if params[:fix_width] == 1
        initial_split = IO.readlines(file_path)
        initial_split.each do |single|
          final_record.push(single.scsan(/.{1,#{params[:fixed_width]}}/m))
        end
      else
        require 'csv'
        CSV.foreach(file_path,:col_sep => params[:sep], :quote_char => params[:delimiter] ,:encoding => 'windows-1251:utf-8') do |single|
          final_record.push(single)
        end
      end
      if params[:rows].to_i && params[:rows].to_i > 1
        final_record.shift(params[:rows].to_i - 1)
      end
      mapping = {}
      params[:map].each do |map_single|
        if map_single[1][:value] != 'none'
          mapping[map_single[1][:value]] = map_single[0].to_i
        end
      end

      order_map = [
          "address_1",
          "address_2",
          "city",
          "country",
          "customer_comments",
          "email",
          "firstname",
          "increment_id",
          "lastname",
          "method",
          "postcode",
          "sku",
          "state",
          "price",
          "qty"
      ]
      imported_orders = {}
      if params[:type] == 'order'
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

        final_record.each_with_index do |single_row,index|
          if !mapping['increment_id'].nil? && mapping['increment_id'] >= 0 && !single_row[mapping['increment_id']].blank?
            import_item.current_increment_id = single_row[mapping['increment_id']]
            import_item.current_order_items = -1
            import_item.current_order_imported_item = -1
            import_item.save
            if imported_orders.has_key?(single_row[mapping['increment_id']]) || Order.where(:increment_id => single_row[mapping['increment_id']]).length == 0
              order = Order.find_or_create_by_increment_id(single_row[mapping['increment_id']])
              order.store_id = params[:store_id]
              #order_placed_time,price,qty
              order_required = ['qty','sku','increment_id']
              order_map.each do |single_map|
                if !mapping[single_map].nil? && mapping[single_map] >= 0
                  #if sku, create order item with product id, qty
                  if single_map == 'sku'
                    import_item.current_order_items = 1
                    import_item.current_order_imported_item = 0
                    import_item.save
                    product_skus = ProductSku.where(:sku => single_row[mapping[single_map]])
                    if product_skus.length > 0
                      if OrderItem.where(:product_id => product_skus.first.product.id, :order_id => order.id).length == 0
                        order_item  = OrderItem.new
                        order_item.product = product_skus.first.product
                        order_item.sku = single_row[mapping['sku']]
                        if !mapping['qty'].nil? && mapping['qty'] >= 0
                          order_item.qty = single_row[mapping['qty']]
                          order_required.delete('qty')
                        end
                        order.order_items << order_item
                      end
                    else # no sku is found
                      product = Product.new
                      product.name = 'Product created from order import'

                      sku = ProductSku.new
                      sku.sku = single_row[mapping['sku']]
                      product.product_skus << sku
                      product.store_product_id = 0
                      product.store_id = params[:store_id]
                      product.save

                      order_item  = OrderItem.new
                      order_item.product = product
                      order_item.sku = single_row[mapping['sku']]
                      if !mapping['qty'].nil? && mapping['qty'] >= 0
                        order_item.qty = single_row[mapping['qty']]
                        order_required.delete('qty')
                      end
                      order.order_items << order_item
                    end
                    import_item.current_order_imported_item = 1
                    import_item.save
                  end
                  #if product id cannot be found with SKU, then create product with product name and SKU


                  order[single_map] = single_row[mapping[single_map]]

                  if order_required.include? single_map
                    order_required.delete(single_map)
                  end
                end
              end
              if order_required.length > 0
                result['status'] = false
                order_required.each do |required_element|
                  result['messages'].push("#{required_element} is missing.")
                end
              end
              if result['status']
                if !mapping['order_placed_time'].nil? && mapping['order_placed_time'] > 0
                  begin
                    require 'time'
                    time = Time.parse(single_row[mapping['order_placed_time']])
                    order['order_placed_time'] = time
                  rescue ArgumentError => e
                    #result["status"] = true
                    result['messages'].push("Order Placed has bad parameter - #{single_row[mapping['order_placed_time']]}")
                  end
                else
                  result['status'] = false
                  result['messages'].push('Order Placed is missing.')
                end
                if result['status']
                  begin
                    #if Order.where(:increment_id=> order.increment_id).length == 0
                    order.status = 'onhold'
                    order.save!
                    imported_orders[order.increment_id] = true
                    order.update_order_status
                    import_item.success_imported = import_item.success_imported + 1
                    import_item.success_imported = import_item.success_imported + 1
                    import_item.save

                      #end
                  rescue ActiveRecord::RecordInvalid => e
                    result['status'] = false
                    result['messages'].push(order.errors.full_messages)
                    import_item.status = 'failed'
                    import_item.message = order.errors.full_messages
                    import_item.save

                  rescue ActiveRecord::StatementInvalid => e
                    result['status'] = false
                    result['messages'].push(e.message)
                    import_item.status = 'failed'
                    import_item.message = e.message
                    import_item.save
                  end
                end
              end
            else
              import_item.previous_imported = import_item.previous_imported + 1
              import_item.save
              #Skipped because of duplicate order
            end
          else
            #No increment id found
            import_item.status = 'failed'
            import_item.message = 'No increment id was found on current order'
            import_item.save
            result['status'] = false
          end
          unless result['status']
            import_item.status = 'failed'
            import_item.message = 'Import halted because of errors, the last imported row was '+index.to_s
            import_item.save
            break
          end
        end

        if result['status']
          import_item.status = 'completed'
          import_item.save
        end
      else

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
              if !mapping['location_primary'].nil? || !mapping['inv_wh1'].nil?
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
                  skus = single_row[mapping['sku']].split(',')
                  skus.each do |single_sku|
                    if ProductSku.where(:sku=>single_sku).length == 0
                      product_sku = ProductSku.new
                      product_sku.sku = single_sku
                      product_sku.purpose = 'primary'
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
      end

      File.delete(file_path)
    else
      result['messages'].push("No file present to import #{params[:type]}")
    end
  end

end
