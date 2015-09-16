module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrdersImporter < CsvBaseImporter
          include ProductsHelper
          
          def import
            result = self.build_result
            order_map = create_order_map
            @imported_orders = {}
            scan_pack_settings = ScanPackSetting.all.first
            @import_item = initialize_import_item
            if self.params[:contains_unique_order_items] == true
              final_record = get_filtered_final_record
            else
              final_record = self.final_record
            end

            final_record.each_with_index do |single_row, index|
              next if is_blank_row(single_row)
              if !self.mapping['increment_id'].nil? && self.mapping['increment_id'][:position] >= 0 && !single_row[self.mapping['increment_id'][:position]].blank?
                @import_item.current_increment_id = single_row[self.mapping['increment_id'][:position]]
                @import_item.current_order_items = -1
                @import_item.current_order_imported_item = -1
                @import_item.save

                if @imported_orders.has_key?(single_row[self.mapping['increment_id'][:position]]) || Order.where(:increment_id => single_row[self.mapping['increment_id'][:position]]).length == 0 || self.params[:contains_unique_order_items] == true
                  @order = Order.find_or_create_by_increment_id(single_row[self.mapping['increment_id'][:position]])
                  @order.store_id = self.params[:store_id]
                  @order_required = ['qty', 'sku', 'increment_id']
                  order_map.each do |single_map|
                    if !self.mapping[single_map].nil? && self.mapping[single_map][:position] >= 0
                      #if sku, create order item with product id, qty
                      if single_map == 'sku' && !self.params[:contains_unique_order_items] == true
                        import_for_nonunique_order_items(single_row, single_map)
                      elsif single_map == 'firstname'
                        if self.mapping['lastname'].nil? || self.mapping['lastname'][:position] == 0
                          arr = single_row[self.mapping[single_map][:position]].blank? ? [] : single_row[self.mapping[single_map][:position]].split(' ')
                          @order.firstname = arr.shift
                          @order.lastname = arr.join(' ')
                        else
                          @order.firstname = single_row[self.mapping[single_map][:position]]
                        end
                      elsif single_map == 'increment_id' && self.params[:contains_unique_order_items] == true && !self.mapping['increment_id'].nil? && !self.mapping['sku'].nil?
                        import_for_unique_order_items(single_row, single_map)
                      else
                        @order[single_map] = single_row[self.mapping[single_map][:position]] unless self.mapping[single_map].nil?
                      end

                      @order_required.delete(single_map) if @order_required.include? single_map
                    end
                  end
                  if @order_required.length > 0
                    result[:status] = false
                    @order_required.each do |required_element|
                      result[:messages].push("#{required_element} is missing.")
                    end
                  end
                  if result[:status]
                    if (!self.mapping['order_placed_time'].nil? && self.mapping['order_placed_time'][:position] >= 0) && (!self.params[:order_date_time_format].nil? && self.params[:order_date_time_format] != 'Default')
                      begin
                        set_order_placed_time(single_row)
                      rescue ArgumentError => e
                        result[:messages].push("Order Placed has bad parameter - #{single_row[self.mapping['order_placed_time'][:position]]}")
                      end
                    elsif !self.params[:order_placed_at].nil?
                      require 'time'
                      time = Time.parse(self.params[:order_placed_at])
                      @order['order_placed_time'] = time
                    else
                      result[:status] = false
                      result[:messages].push('Order Placed is missing.')
                    end
                    if result[:status]
                      result = save_order_and_update_count(result)
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
                result[:status] = false
              end
              unless result[:status]
                @import_item.status = 'failed'
                @import_item.message = 'Import halted because of errors, the last imported row was '+index.to_s+'Errors: '+ result[:messages].join(',')
                @import_item.save
                break
              end
            end

            if result[:status]
              @import_item.status = 'completed'
              @import_item.save
            end
            result
          end

          def import_for_nonunique_order_items(single_row, single_map)
            unless self.mapping['sku'].nil?
              @import_item.current_order_items = 1
              @import_item.current_order_imported_item = 0
              @import_item.save

              product_skus = ProductSku.where(:sku => single_row[self.mapping[single_map][:position]].strip)
              if product_skus.length > 0
                if OrderItem.where(:product_id => product_skus.first.product.id, :order_id => @order.id).length == 0
                  order_item = OrderItem.new
                  order_item.product = product_skus.first.product
                  order_item.sku = single_row[self.mapping['sku'][:position]].strip
                  
                  import_image(order_item.product, single_row, true)
                  if !self.mapping['qty'].nil? && self.mapping['qty'][:position] >= 0
                    order_item.qty = single_row[self.mapping['qty'][:position]]
                    @order_required.delete('qty')
                  end
                  @order.order_items << order_item
                end
              else # no sku is found
                product = Product.new
                set_product_info(product, single_row)
              end
              @import_item.current_order_imported_item = 1
              @import_item.save
            end
          end

          def import_for_unique_order_items(single_row, single_map)
            @order[single_map] = single_row[self.mapping[single_map][:position]]
            @order_required.delete('increment_id')

            @import_item.current_order_items = 1
            @import_item.current_order_imported_item = 0
            @import_item.save

            @order_increment_sku = single_row[self.mapping['increment_id'][:position]]+'-'+single_row[self.mapping['sku'][:position]].strip

            product_skus = ProductSku.where(['sku like (?)', @order_increment_sku+'%'])
            if product_skus.length > 0
              product_sku = product_skus.where(:sku => @order_increment_sku).first
              unless product_sku.nil?
                product_sku.sku = @order_increment_sku + '-1'
                if self.params[:generate_barcode_from_sku] == true
                  product_sku.product.product_barcodes.last.delete
                  product_barcode = ProductBarcode.new
                  product_barcode.barcode = product_sku.sku
                  product_sku.product.product_barcodes << product_barcode
                end
                product_sku.save
              end
              @order_increment_sku = @order_increment_sku + '-' + (product_skus.length+1).to_s
            end
            base_sku = ProductSku.where(:sku => single_row[self.mapping['sku'][:position]].strip).first unless ProductSku.where(:sku => single_row[self.mapping['sku'][:position]].strip).empty?
            if base_sku.nil?
              base_product = Product.new()
              base_product.name = "Base Product " + single_row[self.mapping['sku'][:position]].strip
              base_product.store_product_id = 0
              base_product.store_id = self.params[:store_id]
              base_sku = ProductSku.new
              base_sku.sku = single_row[self.mapping['sku'][:position]].strip
              base_product.product_skus << base_sku
              base_product.is_intangible = false
              import_image(base_product, single_row)
            else
              base_product = base_sku.product
              import_image(base_product, single_row, true)
            end
            base_product.save
            make_product_intangible(base_product)

            product = Product.new
            set_product_info(product, single_row, ture)
          end

          def import_product_name(product, single_row)
            if self.params[:use_sku_as_product_name] == true
              product.name = single_row[self.mapping['sku'][:position]].strip
            elsif !self.mapping['product_name'].nil? && !single_row[self.mapping['product_name'][:position]].nil?
              product.name = single_row[self.mapping['product_name'][:position]]
            else
              product.name = 'Product created from order import'
            end
          end

          def import_product_weight(product, single_row)
            product.weight = single_row[self.mapping['product_weight'][:position]] unless self.mapping['product_weight'].nil? || single_row[self.mapping['product_weight'][:position]].nil?
          end

          def import_product_barcode(product, single_row, unique_order_item = false)
            if self.params[:generate_barcode_from_sku] == true
              product_barcode = ProductBarcode.new
              product_barcode.barcode = get_sku(single_row, unique_order_item)
              product.product_barcodes << product_barcode
            elsif !self.mapping['barcode'].nil? && !single_row[self.mapping['barcode'][:position]].nil?
              if ProductBarcode.where(:barcode => single_row[self.mapping['barcode'][:position]].strip).empty?
                product_barcode = ProductBarcode.new
                product_barcode.barcode = single_row[self.mapping['barcode'][:position]].strip
                product.product_barcodes << product_barcode
              end
            end
          end

          def import_product_category(product, single_row)
            unless self.mapping['category'].nil?
              cat = ProductCat.new
              cat.category = single_row[self.mapping['category'][:position]] unless single_row[self.mapping['category'][:position]].nil?
              product.product_cats << cat
            end
          end

          def import_product_instructions(product, single_row)
            unless self.mapping['product_instructions'].nil? || single_row[self.mapping['product_instructions'][:position]].nil?
              product.spl_instructions_4_packer = single_row[self.mapping['product_instructions'][:position]]
            end
          end

          def import_order_item_qty(order_item, single_row)
            if !self.mapping['qty'].nil? && self.mapping['qty'][:position] >= 0
              order_item.qty = single_row[self.mapping['qty'][:position]]
              @order_required.delete('qty')
            end
          end

          def import_image(product, single_row, check_duplicacy = false)
            if !self.mapping['image'].nil? && self.mapping['image'][:position] >= 0
              if check_duplicacy
                unless is_duplicate_image(product, single_row)
                  import_product_image(product, single_row)
                end
              else
                import_product_image(product, single_row)
              end
            end
          end

          def import_product_image(product, single_row)
            product_image = ProductImage.new
            product_image.image = single_row[self.mapping['image'][:position]]
            product.product_images << product_image
          end

          def is_duplicate_image(product, single_row)
            product_images = product.product_images
            product_images.each do |single_image|
              if single_image.image == single_row[self.mapping['image'][:position]]
                return true
              end
            end
            false
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

            import_item
          end

          def set_product_info(product, single_row, unique_order_item = false)
            product = Product.new
                
            import_product_name(product, single_row)

            import_product_weight(product, single_row)

            sku = ProductSku.new
            sku.sku = single_row[self.mapping['sku'][:position]].strip
            product.product_skus << sku
            
            import_product_barcode(product, single_row, unique_order_item)
            product.store_product_id = 0
            product.store_id = self.params[:store_id]
            import_product_instructions(product, single_row)

            import_image(product, single_row)

            import_product_category(product, single_row)
            if unique_order_item
              product.base_sku = single_row[self.mapping['sku'][:position]].strip unless single_row[self.mapping['sku'][:position]].nil?
            else
              make_product_intangible(product)
            end
            product.save
            product.update_product_status
            order_item = OrderItem.new
            order_item.product = product
            order_item.sku = get_sku(single_row, unique_order_item)
            
            import_order_item_qty(order_item, single_row)
            
            @order_required.delete('sku')
            @order.order_items << order_item

            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def get_sku(single_row, unique_order_item)
            unique_order_item ? @order_increment_sku : (!single_row[self.mapping['sku'][:position]].nil? ? single_row[self.mapping['sku'][:position]].strip : nil)
          end

          def get_filtered_final_record
            existing_order_numbers = []
            filtered_final_record = []
            existing_orders = Order.all
            existing_orders.each do |order|
              existing_order_numbers << order.increment_id
            end
            self.final_record.each_with_index do |single_row, index|
              if !self.mapping['increment_id'].nil? && self.mapping['increment_id'][:position] >= 0 && !single_row[self.mapping['increment_id'][:position]].blank?
                filtered_final_record << single_row unless existing_order_numbers.include? (single_row[self.mapping['increment_id'][:position]])
              end
            end
            filtered_final_record
          end

          def is_blank_row(single_row)
            for i in 0..(single_row.length-1)
              return false unless single_row[i].blank?
            end
            true
          end

          def set_order_placed_time(single_row)
            require 'time'
            imported_order_time = single_row[self.mapping['order_placed_time'][:position]]
            separator = (imported_order_time.include? '/') ? '/' : '-'
            if self.params[:order_date_time_format] == 'YYYY/MM/DD TIME'
              @order['order_placed_time'] = self.params[:day_month_sequence] == 'DD/MM' ? 
              DateTime.strptime(imported_order_time, "%Y#{separator}%d#{separator}%m %H:%M") : 
              DateTime.strptime(imported_order_time, "%Y#{separator}%m#{separator}%d %H:%M")
            elsif self.params[:order_date_time_format] == 'MM/DD/YYYY TIME'
              @order['order_placed_time'] = self.params[:day_month_sequence] == 'DD/MM' ? 
              DateTime.strptime(imported_order_time, "%d#{separator}%m#{separator}%Y %H:%M") : 
              DateTime.strptime(imported_order_time, "%m#{separator}%d#{separator}%Y %H:%M")
            elsif self.params[:order_date_time_format] == 'YY/MM/DD TIME'
              @order['order_placed_time'] = self.params[:day_month_sequence] == 'DD/MM' ? 
              DateTime.strptime(imported_order_time, "%y#{separator}%d#{separator}%m %H:%M") : 
              DateTime.strptime(imported_order_time, "%y#{separator}%m#{separator}%d %H:%M")
            elsif self.params[:order_date_time_format] == 'MM/DD/YY TIME'
              @order['order_placed_time'] = self.params[:day_month_sequence] == 'DD/MM' ? 
              DateTime.strptime(imported_order_time, "%d#{separator}%m#{separator}%y %H:%M") : 
              DateTime.strptime(imported_order_time, "%m#{separator}%d#{separator}%y %H:%M")
            end
          end

          def save_order_and_update_count(result)
            begin
              @order.status = 'onhold'
              @order.save!
              @order.addactivity('Order Import CSV Import', Store.find(self.params[:store_id]).name+" Import")
              @imported_orders[@order.increment_id] = true
              @order.update_order_status
              @import_item.success_imported = @import_item.success_imported + 1
              @import_item.save

            rescue ActiveRecord::RecordInvalid => e
              result[:status] = false
              result[:messages].push(@order.errors.full_messages)
              @import_item.status = 'failed'
              @import_item.message = @order.errors.full_messages
              @import_item.save

            rescue ActiveRecord::StatementInvalid => e
              result[:status] = false
              result[:messages].push(e.message)
              @import_item.status = 'failed'
              @import_item.message = e.message
              @import_item.save
            end
            result
          end
        end
      end
    end
  end
end
