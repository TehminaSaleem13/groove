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
      #final_record.delete_at(0) if final_record.length > 0
      final_record.each_with_index do |single_row,index|
        if params[:type] == 'order'
          if !mapping['increment_id'].nil? && mapping['increment_id'] >= 0 && !single_row[mapping['increment_id']].blank?
            if imported_orders.has_key?(single_row[mapping['increment_id']]) || Order.where(:increment_id => single_row[mapping['increment_id']]).length == 0
              order = Order.find_or_create_by_increment_id(single_row[mapping['increment_id']])
              order.store_id = params[:store_id]
              #order_placed_time,price,qty
              logger.info mapping.to_s
              order_required = ['qty','sku','increment_id']
              order_map.each do |single_map|
                if !mapping[single_map].nil? && mapping[single_map] >= 0
                  #if sku, create order item with product id, qty
                  if single_map == 'sku'
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
                  end
                  #if product id cannot be found with SKU, then create product with product name and SKU


                  order[single_map] = single_row[mapping[single_map]]

                  if order_required.include? single_map
                    order_required.delete(single_map)
                  end
                end
              end
              logger.info order_required.to_s
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
                      #end
                  rescue ActiveRecord::RecordInvalid => e
                    result['status'] = false
                    result['messages'].push(order.errors.full_messages)
                  rescue ActiveRecord::StatementInvalid => e
                    result['status'] = false
                    result['messages'].push(e.message)
                  end
                end
              end
            else
              #Skipped because of duplicate order
            end
          else
            #No increment id found
          end
        else
          if !mapping['sku'].nil? && mapping['sku'] >= 0 && !single_row[mapping['sku']].blank?
            duplicate_found = false
            skus = single_row[mapping['sku']].split(',')

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
        end
        unless result['status']
          result['last_row'] = index
          if index != 0
            result['messages'].push('Import halted because of errors, we have adjusted rows to the ones already imported.')
          end
          break
        end
      end
      File.delete(file_path)
    else
      result['messages'].push("No file present to import #{params[:type]}")
    end
  end

end
