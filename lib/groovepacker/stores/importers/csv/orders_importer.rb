module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrdersImporter
          include ProductsHelper
          
          def import_old
            result = Hash.new
            result['status'] = true
            result['messages'] = []
            order_map = create_order_map
            imported_orders = {}
            scan_pack_settings = ScanPackSetting.all.first
            @import_item = initialize_import_item
            if self.params[:contains_unique_order_items] == true
              existing_order_numbers = []
              filtered_final_record = []
              existing_orders = Order.all
              existing_orders.each do |order|
                existing_order_numbers << order.increment_id
              end
              self.final_record.each_with_index do |single_row, index|
                if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                  unless existing_order_numbers.include? (single_row[mapping['increment_id'][:position]])
                    filtered_final_record << single_row
                  end
                end
              end
              final_record = filtered_final_record
            end

            final_record.each_with_index do |single_row, index|
              do_skip = true
              for i in 0..(single_row.length-1)
                unless single_row[i].blank?
                  do_skip = false
                end
              end
              if do_skip
                next
              else
                if !mapping['increment_id'].nil? && mapping['increment_id'][:position] >= 0 && !single_row[mapping['increment_id'][:position]].blank?
                  @import_item.current_increment_id = single_row[mapping['increment_id'][:position]]
                  @import_item.current_order_items = -1
                  @import_item.current_order_imported_item = -1
                  @import_item.save

                  if imported_orders.has_key?(single_row[mapping['increment_id'][:position]]) || Order.where(:increment_id => single_row[mapping['increment_id'][:position]]).length == 0 || self.params[:contains_unique_order_items] == true
                    order = Order.find_or_create_by_increment_id(single_row[mapping['increment_id'][:position]])
                    order.store_id = self.params[:store_id]
                    #order_placed_time,price,qty
                    order_required = ['qty', 'sku', 'increment_id']
                    order_map.each do |single_map|
                      if !mapping[single_map].nil? && mapping[single_map][:position] >= 0
                        #if sku, create order item with product id, qty
                        if single_map == 'sku' && !self.params[:contains_unique_order_items] == true
                          import_for_unique_order_items(mapping, single_row)
                        elsif single_map == 'firstname'
                          if mapping['lastname'].nil? || mapping['lastname'][:position] == 0
                            arr = single_row[mapping[single_map][:position]].blank? ? [] : single_row[mapping[single_map][:position]].split(' ')
                            order.firstname = arr.shift
                            order.lastname = arr.join(' ')
                          else
                            order.firstname = single_row[mapping[single_map][:position]]
                          end
                        elsif single_map == 'increment_id' && self.params[:contains_unique_order_items] == true && !mapping['increment_id'].nil? && !mapping['sku'].nil?
                          import_for_nonunique_order_items()
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
                      if (!mapping['order_placed_time'].nil? && mapping['order_placed_time'][:position] >= 0) && (!self.params[:order_date_time_format].nil? && self.params[:order_date_time_format] != 'Default')
                        begin
                          require 'time'
                          imported_order_time = single_row[mapping['order_placed_time'][:position]]
                          if imported_order_time.include? ('/')
                            separator = '/'
                          else
                            separator = '-'
                          end
                          if self.params[:order_date_time_format] == 'YYYY/MM/DD TIME'
                            if self.params[:day_month_sequence] == 'DD/MM'
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%Y#{separator}%d#{separator}%m %H:%M")
                            else
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%Y#{separator}%m#{separator}%d %H:%M")
                            end
                          elsif self.params[:order_date_time_format] == 'MM/DD/YYYY TIME'
                            if self.params[:day_month_sequence] == 'DD/MM'
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%d#{separator}%m#{separator}%Y %H:%M")
                            else
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%m#{separator}%d#{separator}%Y %H:%M")
                            end
                          elsif self.params[:order_date_time_format] == 'YY/MM/DD TIME'
                            if self.params[:day_month_sequence] == 'DD/MM'
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%y#{separator}%d#{separator}%m %H:%M")
                            else
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%y#{separator}%m#{separator}%d %H:%M")
                            end
                          elsif self.params[:order_date_time_format] == 'MM/DD/YY TIME'
                            if self.params[:day_month_sequence] == 'DD/MM'
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%d#{separator}%m#{separator}%y %H:%M")
                            else
                              order['order_placed_time'] = DateTime.strptime(imported_order_time, "%m#{separator}%d#{separator}%y %H:%M")
                            end
                          end
                        rescue ArgumentError => e
                          #result["status"] = true
                          result['messages'].push("Order Placed has bad parameter - #{single_row[mapping['order_placed_time'][:position]]}")
                        end
                      elsif !self.params[:order_placed_at].nil?
                        require 'time'
                        time = Time.parse(self.params[:order_placed_at])
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
                          order.addactivity('Order Import CSV Import', Store.find(self.params[:store_id]).name+" Import")
                          imported_orders[order.increment_id] = true
                          order.update_order_status
                          @import_item.success_imported = @import_item.success_imported + 1
                          @import_item.save

                            #end
                        rescue ActiveRecord::RecordInvalid => e
                          result['status'] = false
                          result['messages'].push(order.errors.full_messages)
                          @import_item.status = 'failed'
                          @import_item.message = order.errors.full_messages
                          @import_item.save

                        rescue ActiveRecord::StatementInvalid => e
                          result['status'] = false
                          result['messages'].push(e.message)
                          @import_item.status = 'failed'
                          @import_item.message = e.message
                          @import_item.save
                        end
                      end
                    end
                  else
                    @import_item.previous_imported = @import_item.previous_imported + 1
                    @import_item.save
                    #Skipped because of duplicate order
                  end
                else
                  #No increment id found
                  @import_item.status = 'failed'
                  @import_item.message = 'No increment id was found on current order'
                  @import_item.save
                  result['status'] = false
                end
                unless result['status']
                  @import_item.status = 'failed'
                  @import_item.message = 'Import halted because of errors, the last imported row was '+index.to_s+'Errors: '+ result['messages'].join(',')
                  @import_item.save
                  break
                end
              end
            end

            if result['status']
              @import_item.status = 'completed'
              @import_item.save
            end
            result
          end

          def import_for_unique_order_items(mapping, single_row)
            unless mapping['sku'].nil?
              @import_item.current_order_items = 1
              @import_item.current_order_imported_item = 0
              @import_item.save

              product_skus = ProductSku.where(:sku => single_row[mapping[single_map][:position]].strip)
              if product_skus.length > 0
                if OrderItem.where(:product_id => product_skus.first.product.id, :order_id => order.id).length == 0
                  order_item = OrderItem.new
                  order_item.product = product_skus.first.product
                  order_item.sku = single_row[mapping['sku'][:position]].strip
                  if !mapping['image'].nil? && mapping['image'][:position] >= 0
                    unless is_duplicate_image(order_item.product, single_row, mapping)
                      import_product_image(order_item.product, single_row, mapping)
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
                
                import_product_name(product, self.params, single_row, mapping)

                import_product_weight(product, single_row, mapping)

                sku = ProductSku.new
                sku.sku = single_row[mapping['sku'][:position]].strip
                product.product_skus << sku
                
                import_product_barcode(product, self.params, single_row, mapping)
                product.store_product_id = 0
                product.store_id = self.params[:store_id]
                unless mapping['product_instructions'].nil?
                  product.spl_instructions_4_packer = single_row[mapping['product_instructions'][:position]]
                end

                if !mapping['image'].nil? && mapping['image'][:position] >= 0
                  
                  import_product_image(product, single_row, mapping)
                end

                unless mapping['category'].nil?
                  
                  import_product_category(product, single_row, mapping)
                end

                product.save
                make_product_intangible(product)
                product.update_product_status

                order_item = OrderItem.new
                order_item.product = product
                order_item.sku = single_row[mapping['sku'][:position]].strip
                
                import_order_item_qty(order_required, order_item, single_row, mapping)
                order.order_items << order_item
              end
              @import_item.current_order_imported_item = 1
              @import_item.save
            end
          end

          def import_for_nonunique_order_items()
            order[single_map] = single_row[mapping[single_map][:position]]
            order_required.delete('increment_id')

            @import_item.current_order_items = 1
            @import_item.current_order_imported_item = 0
            @import_item.save

            order_increment_sku = single_row[mapping['increment_id'][:position]]+'-'+single_row[mapping['sku'][:position]].strip

            product_skus = ProductSku.where(['sku like (?)', order_increment_sku+'%'])
            if product_skus.length > 0
              product_sku = product_skus.where(:sku => order_increment_sku).first
              unless product_sku.nil?
                product_sku.sku = order_increment_sku + '-1'
                if self.params[:generate_barcode_from_sku] == true
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
            
            import_product_name(product, self.params, single_row, mapping)

            import_product_weight(product, single_row, mapping)

            import_product_barcode(product, self.params, single_row, mapping)

            sku = ProductSku.new
            sku.sku = order_increment_sku
            product.product_skus << sku
            product.store_product_id = 0
            product.store_id = self.params[:store_id]
            base_sku = ProductSku.where(:sku => single_row[mapping['sku'][:position]].strip).first unless ProductSku.where(:sku => single_row[mapping['sku'][:position]].strip).empty?
            if base_sku.nil?
              base_product = Product.new()
              base_product.name = "Base Product " + single_row[mapping['sku'][:position]].strip
              base_product.store_product_id = 0
              base_product.store_id = self.params[:store_id]
              base_sku = ProductSku.new
              base_sku.sku = single_row[mapping['sku'][:position]].strip
              base_product.product_skus << base_sku
              base_product.is_intangible = false
              if !mapping['image'].nil? && mapping['image'][:position] >= 0
                
                import_product_image(base_product, single_row, mapping)
              end
            else
              base_product = base_sku.product
              if !mapping['image'].nil? && mapping['image'][:position] >= 0
                
                unless is_duplicate_image(base_product, single_row, mapping)
                  import_product_image(base_product, single_row, mapping)
                end
              end
            end
            base_product.save
            make_product_intangible(base_product)

            unless mapping['category'].nil?
              
              import_product_category(product, single_row, mapping)
            end

            unless mapping['product_instructions'].nil?
              product.spl_instructions_4_packer = single_row[mapping['product_instructions'][:position]] unless single_row[mapping['product_instructions'][:position]].nil?
            end
            product.base_sku = single_row[mapping['sku'][:position]].strip unless single_row[mapping['sku'][:position]].nil?
            product.save
            product.update_product_status

            order_item = OrderItem.new
            order_item.product = product
            order_item.sku = order_increment_sku
            import_order_item_qty(order_required, order_item, single_row, mapping)
            
            order_required.delete('sku')
            order.order_items << order_item

            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def import_product_name(product, self.params, single_row, mapping)
            if self.params[:use_sku_as_product_name] == true
              product.name = single_row[mapping['sku'][:position]].strip
            elsif !mapping['product_name'].nil? && !single_row[mapping['product_name'][:position]].nil?
              product.name = single_row[mapping['product_name'][:position]]
            else
              product.name = 'Product created from order import'
            end
          end

          def import_product_weight(product, single_row, mapping)
            unless mapping['product_weight'].nil? || single_row[mapping['product_weight'][:position]].nil?
              product.weight = single_row[mapping['product_weight'][:position]]
            end
          end

          def import_product_barcode(product, self.params, single_row, mapping)
            # if self.params[:generate_barcode_from_sku] == true
            #   product_barcode = ProductBarcode.new
            #   product_barcode.barcode = order_increment_sku
            #   product.product_barcodes << product_barcode
            # elsif !mapping['barcode'].nil? && !single_row[mapping['barcode'][:position]].nil?
            #   product_barcode = ProductBarcode.new
            #   product_barcode.barcode = single_row[mapping['barcode'][:position]].strip
            #   product.product_barcodes << product_barcode
            # end
            if self.params[:generate_barcode_from_sku] == true
              product_barcode = ProductBarcode.new
              product_barcode.barcode = single_row[mapping['sku'][:position]].strip
              product.product_barcodes << product_barcode
            elsif !mapping['barcode'].nil? && !single_row[mapping['barcode'][:position]].nil?
              if ProductBarcode.where(:barcode => single_row[mapping['barcode'][:position]].strip).empty?
                product_barcode = ProductBarcode.new
                product_barcode.barcode = single_row[mapping['barcode'][:position]].strip
                product.product_barcodes << product_barcode
              end
            end
          end

          def import_product_category(product, single_row, mapping)
            cat = ProductCat.new
            cat.category = single_row[mapping['category'][:position]] unless single_row[mapping['category'][:position]].nil?
            product.product_cats << cat
          end

          def import_order_item_qty(order_required, order_item, single_row, mapping)
            if !mapping['qty'].nil? && mapping['qty'][:position] >= 0
              order_item.qty = single_row[mapping['qty'][:position]]
              order_required.delete('qty')
            end
          end

          def import_product_image(product, single_row, mapping)
            product_image = ProductImage.new
            product_image.image = single_row[mapping['image'][:position]]
            product.product_images << product_image
          end

          def is_duplicate_image(product, single_row, mapping)
            product_images = product.product_images
            product_images.each do |single_image|
              if single_image.image == single_row[mapping['image'][:position]]
                return true
              end
            end
            return false
          end

          def create_order_map
            [
              "address_1",
              "address_2",
              "city",
              "country",
              "customer_comments",
              "notes_internal",
              "notes_toPacker",
              "email",
              "firstname",
              "increment_id",
              "lastname",
              "method",
              "postcode",
              "sku",
              "state",
              "price",
              "tracking_num",
              "qty"
            ]
          end

          def initialize_import_item
            import_item = ImportItem.find_by_store_id(self.params[:store_id])
            if import_item.nil?
              import_item = ImportItem.new
              import_item.store_id = self.params[:store_id]
            end
            import_item.status = 'in_progress'
            import_item.current_increment_id = ''
            import_item.success_imported = 0
            import_item.previous_imported = 0
            import_item.current_order_items = -1
            import_item.current_order_imported_item = -1
            import_item.to_import = self.final_record.length
            import_item.save
            return import_item
          end
        end
      end
    end
  end
end
