module Groovepacker
  module Stores
    module Importers
      module CSV
        class OrderImportHelper < CsvBaseImporter
          include ProductsHelper

          def blank_row?(single_row)
            single_row.each do |single_column|
              return false unless single_column.nil?
            end
            true
          end

          def get_row_data(single_row, prop)
            single_row[mapping[prop][:position]]
          end

          def verify_single_item(single_row, item)
            !mapping[item].nil? &&
              mapping[item][:position] >= 0 &&
              !single_row[mapping[item][:position]].nil?
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

          def create_update_base_prod(single_row, single_sku)
            base_skus = ProductSku.where(sku:
              single_sku.strip)
            if base_skus.empty?
              base_product =
                create_base_product(single_sku, single_row)
            elsif base_skus.first
              base_product = update_base_product(base_skus.first, single_row)
            end
            base_product.save
            make_product_intangible(base_product)
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

          def create_base_product(single_sku, single_row)
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

          def import_nonunique_items?(single_map)
            single_map == 'sku' &&
              !params[:contains_unique_order_items] == true
          end

          def import_unique_items?(single_map)
            single_map == 'increment_id' &&
              params[:contains_unique_order_items] == true &&
              !mapping['increment_id'].nil? &&
              !mapping['sku'].nil?
          end

          def update_product(product, single_row)
            import_sec_ter_barcode(product, single_row)
            import_sec_ter_sku(product, single_row)
            product.reload
            product.save!
          end

          def import_product_name(product, single_row)
            if params[:use_sku_as_product_name] == true
              product.name = get_row_data(single_row, 'sku').strip
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

          def push_barcode(product, barcode)
            product_barcode = ProductBarcode.new
            product_barcode.barcode = barcode.strip
            product.product_barcodes << product_barcode
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

          def duplicate_image?(product, single_row)
            product_images = product.product_images
            product_images.each do |single_image|
              return true if
                single_image.image == get_row_data(single_row, 'image')
            end
            false
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

          def order_placed_time_mapped?(single_row)
            verify_single_item(single_row, 'order_placed_time') &&
              !params[:order_date_time_format].nil? &&
              params[:order_date_time_format] != 'Default'
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
        end
      end
    end
  end
end
