module Groovepacker
  module Store
    module Importers
      module CSV
        class OrdersImporter
          def import(params,final_record,mapping)
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

            final_record.each_with_index do |single_row,index|
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

          def import_old(params,final_record,mapping)
            puts "parms:::::: " + params.inspect
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

            final_record.each_with_index do |single_row,index|
              if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                import_item.current_increment_id = single_row[mapping['increment_id'][:position]]
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.save

                if imported_orders.has_key?(single_row[mapping['increment_id'][:position]]) || Order.where(:increment_id => single_row[mapping['increment_id'][:position]]).length == 0 || params[:contains_unique_order_items] == true
                  order = Order.find_or_create_by_increment_id(single_row[mapping['increment_id'][:position]])
                  order.store_id = params[:store_id]
                  #order_placed_time,price,qty
                  order_required = ['qty','sku','increment_id']
                  order_map.each do |single_map|
                    if !mapping[single_map].nil? && mapping[single_map][:position] >= 0
                      #if sku, create order item with product id, qty
                      if single_map == 'sku'
                        import_item.current_order_items = 1
                        import_item.current_order_imported_item = 0
                        import_item.save

                        product_skus = ProductSku.where(:sku => single_row[mapping[single_map][:position]])
                        if product_skus.length > 0
                          if OrderItem.where(:product_id => product_skus.first.product.id, :order_id => order.id).length == 0
                            order_item  = OrderItem.new
                            order_item.product = product_skus.first.product
                            order_item.sku = single_row[mapping['sku'][:position]]
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
                          end
                          product.store_product_id = 0
                          product.store_id = params[:store_id]
                          product.save

                          order_item  = OrderItem.new
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
                      elsif single_map == 'firstname'
                        if mapping['lastname'].nil? || mapping['lastname'][:position] == 0
                          arr = single_row[mapping[single_map][:position]].blank? ? [] : single_row[mapping[single_map][:position]].split(' ')
                          order.firstname = arr.shift
                          order.lastname = arr.join(' ')
                        else
                          order.firstname = single_row[mapping[single_map][:position]]
                        end
                      elsif single_map == 'increment_id' && params[:contains_unique_order_items] == true
                        order[single_map] = single_row[mapping[single_map][:position]]
                        order_required.delete('increment_id')

                        import_item.current_order_items = 1
                        import_item.current_order_imported_item = 0
                        import_item.save
                        
                        order_increment_sku = single_row[mapping['increment_id'][:position]]+'-'+single_row[mapping['base_sku'][:position]]
                        
                        product_skus = ProductSku.where(['sku like (?)', order_increment_sku+'%'])
                        if product_skus.length > 0
                          product_sku = product_skus.where(:sku=>order_increment_sku).first
                          unless product_sku.nil?
                            product_sku.sku = order_increment_sku + '-1'
                            product_sku.save
                          end
                          order_increment_sku = order_increment_sku + '-' + (product_skus.length+1).to_s 
                        end

                        product = Product.new
                        if params[:use_sku_as_product_name] == true
                          product.name = order_increment_sku
                        else
                          unless single_row[mapping['product_name'][:position]].nil?
                            product.name = single_row[mapping['product_name'][:position]]
                          else
                            product.name = 'Product created from order import'
                          end
                        end

                        if params[:generate_barcode_from_sku] == true
                          product_barcode = ProductBarcode.new
                          product_barcode.barcode = order_increment_sku
                          product.product_barcodes << product_barcode
                        end
                                      
                        sku = ProductSku.new
                        sku.sku = order_increment_sku
                        product.product_skus << sku
                        product.store_product_id = 0
                        product.store_id = params[:store_id]
                        base_product = ProductSku.where(:sku=>single_row[mapping['base_sku'][:position]]).first unless ProductSku.where(:sku=>single_row[mapping['base_sku'][:position]]).empty?
                        if base_product.nil?
                          base_product = Product.new()
                          base_product.name = "Base Product " + single_row[mapping['base_sku'][:position]]
                          base_product.store_product_id = 0
                          base_product.store_id = params[:store_id]
                          basesku = ProductSku.new
                          basesku.sku = single_row[mapping['base_sku'][:position]]
                          base_product.product_skus << basesku
                          base_product.save
                        end
                        product.spl_instructions_4_packer = single_row[mapping['customer_comments'][:position]] unless single_row[mapping['customer_comments'][:position]].nil?
                        product.base_sku = single_row[mapping['base_sku'][:position]] unless single_row[mapping['base_sku'][:position]].nil?
                        product.save

                        order_item  = OrderItem.new
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
                        order[single_map] = single_row[mapping[single_map][:position]]
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
                    if !mapping['order_placed_time'].nil? && mapping['order_placed_time'][:position] >= 0
                      begin
                        require 'time'
                        time = Time.parse(single_row[mapping['order_placed_time'][:position]])
                        order['order_placed_time'] = time
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
