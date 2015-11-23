module Groovepacker
  module Stores
    module Importers
      module CSV
        # The following class imports orders and conatining items
        # for each order from a csv file.
        class OrdersImporter < CsvBaseImporter
          include ProductsHelper
          def import
            result = build_result
            order_map = create_order_map
            @imported_orders = {}
            @import_item = initialize_import_item
            if params[:contains_unique_order_items] == true
              final_records = build_filtered_final_record
            else
              final_records = final_record
            end

            final_records.each_with_index do |single_row, index|
              next if blank_row?(single_row)
              if  verify_single_item(single_row, 'increment_id') &&
                  verify_single_item(single_row, 'sku')
                @import_item.current_increment_id = inc_id = get_row_data(single_row, 'increment_id')
                @import_item.current_order_items = -1
                @import_item.current_order_imported_item = -1
                @import_item.save

                if  @imported_orders.key?(inc_id) ||
                    Order.where(
                      increment_id: inc_id).length == 0 ||
                    params[:contains_unique_order_items] == true
                  @order = Order.find_or_create_by_increment_id(
                    inc_id)
                  @order.store_id = params[:store_id]
                  @order_required = %w(qty sku increment_id price)
                  order_map.each do |single_map|
                    next unless !mapping[single_map].nil? &&
                                mapping[single_map][:position] >= 0
                    # if sku, create order item with product id, qty
                    if  single_map == 'sku' &&
                        !params[:contains_unique_order_items] == true
                      import_for_nonunique_order_items(single_row)
                    elsif single_map == 'firstname'
                      if  mapping['lastname'].nil? ||
                          mapping['lastname'][:position] == 0
                        arr = single_row[mapping[single_map][:position]].blank? ? [] : get_row_data(single_row, single_map).split(' ')
                        @order.firstname = arr.shift
                        @order.lastname = arr.join(' ')
                      else
                        @order.firstname = single_row[mapping[single_map][:position]]
                      end
                    elsif single_map == 'increment_id' &&
                          params[:contains_unique_order_items] == true &&
                          !mapping['increment_id'].nil? &&
                          !mapping['sku'].nil?
                      import_for_unique_order_items(single_row)
                    else
                      @order[single_map] =
                        get_row_data(single_row, single_map) if mapping[single_map]
                    end

                    @order_required.delete(single_map) if @order_required.include? single_map
                  end
                  if @order_required.length > 0
                    result[:status] = false
                    @order_required.each do |required_element|
                      result[:messages].push("#{required_element} is missing.")
                    end
                  end
                  if result[:status]
                    if  !mapping['order_placed_time'].nil? &&
                        mapping['order_placed_time'][:position] >= 0 &&
                        !params[:order_date_time_format].nil? &&
                        params[:order_date_time_format] != 'Default'
                      begin
                        calculate_order_placed_time(single_row)
                      rescue
                        result[:messages].push('Order Placed has bad parameter - ' \
                          "#{single_row[mapping['order_placed_time'][:position]]}")
                      end
                    elsif !params[:order_placed_at].nil?
                      require 'time'
                      time = Time.parse(params[:order_placed_at])
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
                  @import_item.previous_imported += 1
                  @import_item.save
                  # Skipped because of duplicate order
                end
              else
                next
              end
              next if result[:status]
              @import_item.status = 'failed'
              @import_item.message =  'Import halted because of ' \
                                      'errors, the last imported row was ' +
                                      index.to_s + 'Errors: ' +
                                      result[:messages].join(',')
              @import_item.save
              break
            end

            if result[:status]
              @import_item.status = 'completed'
              @import_item.save
            end
          end

          def import_for_nonunique_order_items(single_row)
            return if mapping['sku'].nil?
            @import_item.current_order_items = 1
            @import_item.current_order_imported_item = 0
            @import_item.save
            single_sku = get_row_data(single_row, 'sku')
            product_skus = ProductSku.where(
              sku: single_sku.strip)
            if !product_skus.empty?
              product = product_skus.first.product
              order_items = OrderItem.where(
                product_id: product.id,
                order_id: @order.id)
              if order_items.empty?
                order_item = import_new_order_item(single_row, product, single_sku)
                import_image(product, single_row, true)
              else
                order_item = update_order_item(single_row, product, single_sku)
              end
              save_order_item(order_item)
              import_sec_ter_barcode(product, single_row)
              import_sec_ter_sku(product, single_row)
              product.reload
              product.save!
            else # no sku is found
              product = Product.new
              set_product_info(product, single_row)
            end
            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def order_item_value(item, order_item, single_row)
            if verify_single_item(single_row, item)
              case item
              when 'qty'
                order_item.qty = get_row_data(single_row, item)
              when 'item_sale_price'
                order_item.price = get_row_data(single_row, item)
              end
            else
              case item
              when 'qty'
                order_item.qty = 0
              when 'item_sale_price'
                order_item.price = 0.0
              end
            end
          end

          def import_new_order_item(single_row, product, single_sku)
            order_item = OrderItem.new
            order_item.product = product
            order_item.sku = single_sku.strip
            %w(qty item_sale_price).each do |item|
              order_item_value(item, order_item, single_row)
            end
            order_item
          end

          def update_order_item(single_row, product, single_sku)
            order_item = OrderItem.where(
              product_id: product.id,
              order_id: @order.id,
              sku: single_sku.strip).first
            import_image(product, single_row, true)
            %w(qty item_sale_price).each do |item|
              next unless verify_single_item(single_row, item)
              case item
              when 'qty'
                order_item.qty =  (order_item.qty.to_i +
                                  get_row_data(single_row, 'qty').to_i).to_s
              when 'item_sale_price'
                order_item.price =
                  get_row_data(single_row, 'item_sale_price')
              end
            end
            order_item
          end

          def verify_single_item(single_row, item)
            !mapping[item].nil? &&
              mapping[item][:position] >= 0 &&
              !single_row[mapping[item][:position]].nil?
          end

          def import_for_unique_order_items(single_row)
            single_inc_id = get_row_data(single_row, 'increment_id')
            @order['increment_id'] = single_inc_id
            @order_required.delete('increment_id')
            single_sku = get_row_data(single_row, 'sku')
            @import_item.current_order_items = 1
            @import_item.current_order_imported_item = 0
            @import_item.save

            @order_increment_sku = single_inc_id + '-' + single_sku.strip
            product_skus = ProductSku.where(
              ['sku like (?)', @order_increment_sku + '%'])
            unless product_skus.empty?
              product_sku = product_skus.where(sku: @order_increment_sku).first
              if product_sku
                product_sku.sku = @order_increment_sku + '-1'
                if params[:generate_barcode_from_sku] == true
                  product_sku.product.product_barcodes.last.delete
                  product_barcode = ProductBarcode.new
                  product_barcode.barcode = product_sku.sku
                  product_sku.product.product_barcodes << product_barcode
                end
                product_sku.save
              end
              @order_increment_sku =  @order_increment_sku + '-' +
                                      (product_skus.length + 1).to_s
            end
            base_sku = ProductSku.where(sku:
              single_sku.strip).first unless
              ProductSku.where(sku: single_sku.strip).empty?
            if base_sku.nil?
              base_product =
                create_base_product(base_sku, single_sku, single_row)
            else
              base_product = update_base_product(base_sku, single_row)
            end
            base_product.save
            make_product_intangible(base_product)
            product = Product.new
            set_product_info(product, single_row, true)
          end

          def create_base_product(base_sku, single_sku, single_row)
            base_product = Product.new
            base_product.name = 'Base Product ' + single_sku.strip
            base_product.store_product_id = 0
            base_product.store_id = params[:store_id]
            base_sku = ProductSku.new
            base_sku.sku = single_sku.strip
            base_product.product_skus << base_sku
            base_product.is_intangible = false
            import_image(base_product, single_row)
            base_product
          end

          def update_base_product(base_sku, single_row)
            base_product = base_sku.product
            import_image(base_product, single_row, true)
            import_sec_ter_barcode(base_product, single_row)
            import_sec_ter_sku(base_product, single_row)
            base_product
          end

          def import_product_name(product, single_row)
            if params[:use_sku_as_product_name] == true
              product.name = single_row[mapping['sku'][:position]].strip
            elsif verify_single_item(single_row, 'product_name')
              product.name = get_row_data(single_row, 'product_name')
            else
              product.name = 'Product created from order import'
            end
          end

          def import_product_weight(product, single_row)
            product.weight = get_row_data(single_row, 'product_weight') if
            verify_single_item(single_row, 'product_weight')
          end

          def import_product_barcode(product, single_row, unique_order_item = false)
            if params[:generate_barcode_from_sku] == true
              push_barcode(product, get_sku(single_row, unique_order_item))
            elsif verify_single_item(single_row, 'barcode')
              barcode = get_row_data(single_row, 'barcode')
              if ProductBarcode.where(
                barcode: barcode.strip).empty?
                push_barcode(product, barcode)
              end
            end
          end

          def push_barcode(product, barcode)
            product_barcode = ProductBarcode.new
            product_barcode.barcode = barcode.strip
            product.product_barcodes << product_barcode
          end

          def import_product_info(product, single_row, prop, prop_type)
            return unless verify_single_item(single_row, prop)
            if prop_type == 'barcode'
              barcode = ProductBarcode.new
              barcode.barcode = get_row_data(single_row, prop)
              product.product_barcodes << barcode
            elsif prop_type == 'sku'
              sku = ProductSku.new
              sku.sku = get_row_data(single_row, prop)
              product.product_skus << sku
            elsif prop_type == 'category'
              cat = ProductCat.new
              cat.category = get_row_data(single_row, prop)
              product.product_cats << cat
            end
          end

          def import_sec_ter_barcode(product, single_row)
            %w(secondary_barcode tertiary_barcode).each do |prop|
              import_product_info(product, single_row, prop, 'barcode')
            end
          end

          def import_sec_ter_sku(product, single_row)
            %w(secondary_sku tertiary_sku).each do |prop|
              import_product_info(product, single_row, prop, 'sku')
            end
          end

          def import_product_category(product, single_row)
            import_product_info(product, single_row, 'category', 'category')
          end

          def import_product_instructions(single_row)
            get_row_data(single_row, 'product_instructions') if
              verify_single_item(single_row, 'product_instructions')
          end

          def import_image(product, single_row, check_duplicacy = false)
            return unless verify_single_item(single_row, 'image')
            if check_duplicacy
              unless duplicate_image?(product, single_row)
                import_product_image(product, single_row)
              end
            else
              import_product_image(product, single_row)
            end
          end

          def import_product_image(product, single_row)
            product_image = ProductImage.new
            product_image.image = get_row_data(single_row, 'image')
            product.product_images << product_image
          end

          def import_product_sku(product, single_row, unique_order_item = false)
            sku = ProductSku.new
            # sku.sku = single_row[mapping['sku'][:position]].strip
            sku.sku = get_sku(single_row, unique_order_item)
            product.product_skus << sku
          end

          def duplicate_image?(product, single_row)
            product_images = product.product_images
            product_images.each do |single_image|
              return true if
                single_image.image == get_row_data(single_row, 'image')
            end
            false
          end

          def create_order_map
            %w( address_1 address_2 city country customer_comments
                notes_internal notes_toPacker email firstname increment_id
                lastname method postcode sku state price tracking_num qty)
          end

          def initialize_import_item
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

            import_item
          end

          def set_product_info(product, single_row, unique_order_item = false)
            import_product_data(product, single_row, unique_order_item)
            product.reload
            product.update_product_status
            order_item = import_new_order_item(
              single_row, product,
              get_sku(single_row, unique_order_item))
            @order_required.delete('sku')
            save_order_item(order_item)

            @import_item.current_order_imported_item = 1
            @import_item.save
          end

          def import_product_data(product, single_row, unique_order_item)
            import_product_name(product, single_row)
            import_product_weight(product, single_row)
            import_product_sku(product, single_row, unique_order_item)
            import_product_barcode(product, single_row, unique_order_item)
            product.store_product_id = 0
            product.store_id = params[:store_id]
            product.spl_instructions_4_packer =
              import_product_instructions(single_row)
            import_image(product, single_row)
            import_product_category(product, single_row)
            if unique_order_item
              product.base_sku = get_row_data(single_row, 'sku').strip
              product.save
            else
              import_sec_ter_sku(product, single_row)
              import_sec_ter_barcode(product, single_row)
              make_product_intangible(product) if product.save!
            end
          end

          def save_order_item(order_item)
            @order_required.delete('qty')
            @order_required.delete('price')
            @order.order_items << order_item
          end

          def get_sku(single_row, unique_order_item)
            unique_order_item ? @order_increment_sku : get_row_data(single_row, 'sku').strip
          end

          def build_filtered_final_record
            existing_order_numbers = []
            filtered_final_record = []
            existing_orders = Order.all
            existing_orders.each do |order|
              existing_order_numbers << order.increment_id
            end
            final_record.each do |single_row|
              next unless verify_single_item(single_row, 'increment_id')
              filtered_final_record << single_row unless
                existing_order_numbers.include? get_row_data(single_row, 'increment_id')
            end
            filtered_final_record
          end

          def blank_row?(single_row)
            single_row.each do |single_column|
              return false unless single_column.nil?
            end
            true
          end

          def get_row_data(single_row, prop)
            single_row[mapping[prop][:position]]
          end

          def calculate_order_placed_time(single_row)
            require 'time'
            imported_order_time =
              get_row_data(single_row, 'order_placed_time')
            separator = (imported_order_time.include? '/') ? '/' : '-'
            order_time_hash = build_order_time_hash(separator)
            @order['order_placed_time'] = DateTime.strptime(
              imported_order_time,
              order_time_hash[params[:order_date_time_format]][params[:day_month_sequence]])
          end

          def build_order_time_hash(separator)
            {
              'YYYY/MM/DD TIME' => {
                'DD/MM' => "%Y#{separator}%d#{separator}%m %H:%M",
                'MM/DD' => "%Y#{separator}%m#{separator}%d %H:%M"
              },
              'MM/DD/YYYY TIME' => {
                'DD/MM' => "%d#{separator}%m#{separator}%Y %H:%M",
                'MM/DD' => "%m#{separator}%d#{separator}%Y %H:%M"
              },
              'YY/MM/DD TIME' => {
                'DD/MM' => "%y#{separator}%d#{separator}%m %H:%M",
                'MM/DD' => "%y#{separator}%m#{separator}%d %H:%M"
              },
              'MM/DD/YY TIME' => {
                'DD/MM' => "%d#{separator}%m#{separator}%y %H:%M",
                'MM/DD' => "%m#{separator}%d#{separator}%y %H:%M"
              }
            }
          end

          def update_count_error_result(result, messages)
            result[:status] = false
            result[:messages] = messages
            @import_item.status = 'failed'
            @import_item.message = messages
            @import_item.save
            result
          end

          def update_status_and_save
            @order.status = 'onhold'
            @order.save!
            @order.addactivity(
              'Order Import CSV Import',
              Store.find(params[:store_id]).name + ' Import')
            @order.update_order_status
          end

          def save_order_and_update_count(result)
            begin
              update_status_and_save
              @imported_orders[@order.increment_id] = true
              @import_item.success_imported += 1
              @import_item.save
            rescue ActiveRecord::RecordInvalid => e
              messages = @order.errors.full_messages + e.message
              result = update_count_error_result(result, messages)
            rescue ActiveRecord::StatementInvalid => e
              result = update_count_error_result(result, e.messages)
            end
            result
          end
        end
      end
    end
  end
end
