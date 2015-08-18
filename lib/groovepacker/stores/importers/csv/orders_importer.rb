module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrdersImporter
          include ProductsHelper

          def import(params, final_record, mapping)
            result = Hash.new
            result['status'] = true
            result['messages'] = []
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

            final_record.each_with_index do |single_row, index|
              if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                import_item.current_increment_id = single_row[mapping['increment_id'][:position]]
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.save
                # Actual importer
                import_item.success_imported = import_item.success_imported + 1
                import_item.save
              end
            end
            import_item.status = 'completed'
            import_item.save
            result
          end

          def import_old(params, final_record, mapping)
            result = Hash.new
            result['status'] = true
            result['messages'] = []
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
              "tracking_num"
            ]
            imported_orders = {}
            scan_pack_settings = ScanPackSetting.all.first
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
            if params[:contains_unique_order_items] == true
              existing_order_numbers = []
              filtered_final_record = []
              existing_orders = Order.all
              existing_orders.each do |order|
                existing_order_numbers << order.increment_id
              end
              final_record.each_with_index do |single_row, index|
                if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                  unless existing_order_numbers.include? (single_row[mapping['increment_id'][:position]])
                    filtered_final_record << single_row
                  end
                end
              end
              final_record = filtered_final_record
            end

            final_record.each_with_index do |single_row, index|
              if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                import_item.current_increment_id = single_row[mapping['increment_id'][:position]]
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.save

                if imported_orders.has_key?(single_row[mapping['increment_id'][:position]]) || Order.where(:increment_id => single_row[mapping['increment_id'][:position]]).length == 0 || params[:contains_unique_order_items] == true
                  order = Order.find_or_create_by_increment_id(single_row[mapping['increment_id'][:position]])
                  order.store_id = params[:store_id]
                  #order_placed_time,price,qty
                  order_required = ['qty', 'sku', 'increment_id']
                  order_map.each do |single_map|
                    if !mapping[single_map].nil? && mapping[single_map][:position] >= 0
                      #if sku, create order item with product id, qty
                      if single_map == 'sku' && !params[:contains_unique_order_items] == true
                        unless mapping['sku'].nil?
                          import_item.current_order_items = 1
                          import_item.current_order_imported_item = 0
                          import_item.save

                          product_skus = ProductSku.where(:sku => single_row[mapping[single_map][:position]])
                          if product_skus.length > 0
                            if OrderItem.where(:product_id => product_skus.first.product.id, :order_id => order.id).length == 0
                              order_item = OrderItem.new
                              order_item.product = product_skus.first.product
                              order_item.sku = single_row[mapping['sku'][:position]]
                              if !mapping['image'].nil? && mapping['image'][:position] >= 0
                                product_images = order_item.product.product_images
                                exists = false
                                product_images.each do |single_image|
                                  if single_image.image == single_row[mapping['image'][:position]]
                                    exists = true
                                    break
                                  end
                                end
                                unless exists
                                  product_image = ProductImage.new
                                  product_image.image = single_row[mapping['image'][:position]]
                                  order_item.product.product_images << product_image
                                end
                              end
                              if !mapping['qty'].nil? && mapping['qty'][:position] >= 0
                                order_item.qty = single_row[mapping['qty'][:position]]
                                order_required.delete('qty')
                              end
                              order.order_items << order_item
                            end
                          else # no sku is found
                            product = Product.new
                            if params[:use_sku_as_product_name] == true
                              product.name = single_row[mapping['sku'][:position]]
                            elsif !mapping['product_name'].nil?
                              product.name = single_row[mapping['product_name'][:position]]
                            else
                              product.name = 'Product created from order import'
                            end

                            sku = ProductSku.new
                            sku.sku = single_row[mapping['sku'][:position]]
                            product.product_skus << sku
                            if params[:generate_barcode_from_sku] == true
                              product_barcode = ProductBarcode.new
                              product_barcode.barcode = single_row[mapping['sku'][:position]]
                              product.product_barcodes << product_barcode
                            elsif !mapping['barcode'].nil? && !single_row[mapping['barcode'][:position]].nil?
                              product_barcode = ProductBarcode.new
                              product_barcode.barcode = single_row[mapping['barcode'][:position]]
                              product.product_barcodes << product_barcode
                            end
                            product.store_product_id = 0
                            product.store_id = params[:store_id]
                            unless mapping['product_instructions'].nil?
                              product.spl_instructions_4_packer = single_row[mapping['product_instructions'][:position]]
                            end

                            if !mapping['image'].nil? && mapping['image'][:position] >= 0
                              product_image = ProductImage.new
                              product_image.image = single_row[mapping['image'][:position]]
                              product.product_images << product_image
                            end

                            product.save
                            make_product_intangible(product)
                            product.update_product_status

                            order_item = OrderItem.new
                            order_item.product = product
                            order_item.sku = single_row[mapping['sku'][:position]]
                            if !mapping['qty'].nil? && mapping['qty'][:position] >= 0
                              order_item.qty = single_row[mapping['qty'][:position]]
                              order_required.delete('qty')
                            end
                            order.order_items << order_item
                          end
                          import_item.current_order_imported_item = 1
                          import_item.save
                        end

                      elsif single_map == 'firstname'
                        if mapping['lastname'].nil? || mapping['lastname'][:position] == 0
                          arr = single_row[mapping[single_map][:position]].blank? ? [] : single_row[mapping[single_map][:position]].split(' ')
                          order.firstname = arr.shift
                          order.lastname = arr.join(' ')
                        else
                          order.firstname = single_row[mapping[single_map][:position]]
                        end
                      elsif single_map == 'increment_id' && params[:contains_unique_order_items] == true && !mapping['increment_id'].nil? && !mapping['sku'].nil?
                        order[single_map] = single_row[mapping[single_map][:position]]
                        order_required.delete('increment_id')

                        import_item.current_order_items = 1
                        import_item.current_order_imported_item = 0
                        import_item.save

                        order_increment_sku = single_row[mapping['increment_id'][:position]]+'-'+single_row[mapping['sku'][:position]]

                        product_skus = ProductSku.where(['sku like (?)', order_increment_sku+'%'])
                        if product_skus.length > 0
                          product_sku = product_skus.where(:sku => order_increment_sku).first
                          unless product_sku.nil?
                            product_sku.sku = order_increment_sku + '-1'
                            if params[:generate_barcode_from_sku] == true
                              product_sku.product.product_barcodes.last.delete
                              product_barcode = ProductBarcode.new
                              product_barcode.barcode = product_sku.sku
                              product_sku.product.product_barcodes << product_barcode
                            end
                            product_sku.save
                          end
                          order_increment_sku = order_increment_sku + '-' + (product_skus.length+1).to_s
                        end

                        product = Product.new
                        if params[:use_sku_as_product_name] == true
                          product.name = order_increment_sku
                        else
                          unless mapping['product_name'].nil? || single_row[mapping['product_name'][:position]].nil?
                            product.name = single_row[mapping['product_name'][:position]]
                          else
                            product.name = 'Product created from order import'
                          end
                        end

                        if params[:generate_barcode_from_sku] == true
                          product_barcode = ProductBarcode.new
                          product_barcode.barcode = order_increment_sku
                          product.product_barcodes << product_barcode
                        elsif !mapping['barcode'].nil? && !single_row[mapping['barcode'][:position]].nil?
                          product_barcode = ProductBarcode.new
                          product_barcode.barcode = single_row[mapping['barcode'][:position]]
                          product.product_barcodes << product_barcode
                        end

                        sku = ProductSku.new
                        sku.sku = order_increment_sku
                        product.product_skus << sku
                        product.store_product_id = 0
                        product.store_id = params[:store_id]
                        base_sku = ProductSku.where(:sku => single_row[mapping['sku'][:position]]).first unless ProductSku.where(:sku => single_row[mapping['sku'][:position]]).empty?
                        if base_sku.nil?
                          base_product = Product.new()
                          base_product.name = "Base Product " + single_row[mapping['sku'][:position]]
                          base_product.store_product_id = 0
                          base_product.store_id = params[:store_id]
                          base_sku = ProductSku.new
                          base_sku.sku = single_row[mapping['sku'][:position]]
                          base_product.product_skus << base_sku
                          base_product.is_intangible = false
                          if !mapping['image'].nil? && mapping['image'][:position] >= 0
                            product_image = ProductImage.new
                            product_image.image = single_row[mapping['image'][:position]]
                            base_product.product_images << product_image
                          end
                        else
                          base_product = base_sku.product
                          if !mapping['image'].nil? && mapping['image'][:position] >= 0
                            product_images = base_product.product_images
                            exists = false
                            product_images.each do |single_image|
                              if single_image.image == single_row[mapping['image'][:position]]
                                exists = true
                                break
                              end
                            end
                            unless exists
                              product_image = ProductImage.new
                              product_image.image = single_row[mapping['image'][:position]]
                              base_product.product_images << product_image
                            end
                          end
                        end
                        base_product.save
                        make_product_intangible(base_product)

                        unless mapping['category'].nil?
                          cat = ProductCat.new
                          cat.category = single_row[mapping['category'][:position]] unless single_row[mapping['category'][:position]].nil?
                          product.product_cats << cat
                        end

                        unless mapping['product_instructions'].nil?
                          product.spl_instructions_4_packer = single_row[mapping['product_instructions'][:position]] unless single_row[mapping['product_instructions'][:position]].nil?
                        end
                        product.base_sku = single_row[mapping['sku'][:position]] unless single_row[mapping['sku'][:position]].nil?
                        product.save
                        product.update_product_status

                        order_item = OrderItem.new
                        order_item.product = product
                        order_item.sku = order_increment_sku
                        if !mapping['qty'].nil? && mapping['qty'][:position] >= 0
                          order_item.qty = single_row[mapping['qty'][:position]]
                          order_required.delete('qty')
                        end
                        order_required.delete('sku')
                        order.order_items << order_item

                        import_item.current_order_imported_item = 1
                        import_item.save
                      else
                        unless mapping[single_map].nil?
                          order[single_map] = single_row[mapping[single_map][:position]]
                        end
                      end

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
                    if !mapping['order_placed_time'].nil? && mapping['order_placed_time'][:position] >= 0 && !params[:order_date_time_format].nil?
                      begin
                        require 'time'
                        imported_order_time = single_row[mapping['order_placed_time'][:position]]
                        if params[:order_date_time_format] == 'YYYY/MM/DD TIME'
                          if params[:day_time_sequence] == 'MM/DD'
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%Y/%m/%d %H:%M")
                          else
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%Y/%d/%m %H:%M")
                          end
                        elsif params[:order_date_time_format] == 'MM/DD/YYYY TIME'
                          if params[:day_time_sequence] == 'MM/DD'
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%m/%d/%Y %H:%M")
                          else
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%d/%m/%Y %H:%M")
                          end
                        elsif params[:order_date_time_format] == 'YY/MM/DD TIME'
                          if params[:day_time_sequence] == 'MM/DD'
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%y/%m/%d %H:%M")
                          else
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%y/%d/%m %H:%M")
                          end
                        elsif params[:order_date_time_format] == 'MM/DD/YY TIME'
                          if params[:day_time_sequence] == 'MM/DD'
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%m/%d/%y %H:%M")
                          else
                            order['order_placed_time'] = DateTime.strptime(imported_order_time, "%d/%m/%y %H:%M")
                          end
                        end
                      rescue ArgumentError => e
                        #result["status"] = true
                        result['messages'].push("Order Placed has bad parameter - #{single_row[mapping['order_placed_time'][:position]]}")
                      end
                    elsif !params[:order_placed_at].nil?
                      require 'time'
                      time = Time.parse(params[:order_placed_at])
                      order['order_placed_time'] = time
                    else
                      result['status'] = false
                      result['messages'].push('Order Placed is missing.')
                    end
                    if result['status']
                      begin
                        #if Order.where(:increment_id=> order.increment_id).length == 0
                        order.status = 'onhold'
                        order.save!
                        order.addactivity('Order Import CSV Import')
                        imported_orders[order.increment_id] = true
                        order.update_order_status
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
                import_item.message = 'Import halted because of errors, the last imported row was '+index.to_s+'Errors: '+ result['messages'].join(',')
                import_item.save
                break
              end
            end

            if result['status']
              import_item.status = 'completed'
              import_item.save
            end
            result
          end
        end
      end
    end
  end
end
