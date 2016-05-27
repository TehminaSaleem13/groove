module Groovepacker
  module Stores
    module Importers
      module CSV
        class ProductImportHelper < CsvBaseImporter
          include ProductsHelper

          def initiate_helper
            @helper = Groovepacker::Stores::Importers::CSV::OrderImportHelper.new(params, final_record, mapping, import_action)
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
            base_product
          end

          def import_product_info(product, single_row, prop, prop_type)
            return unless @helper.verify_single_item(single_row, prop)
            if prop_type == 'barcode'
              barcode = ProductBarcode.new
              barcode.barcode = @helper.get_row_data(single_row, prop)
              product.product_barcodes << barcode
            elsif prop_type == 'sku'
              sku = ProductSku.new
              sku.sku = @helper.get_row_data(single_row, prop)
              product.product_skus << sku
            elsif prop_type == 'category'
              cat = ProductCat.new
              cat.category = @helper.get_row_data(single_row, prop)
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

          def update_product(product, single_row)
            import_sec_ter_barcode(product, single_row)
            import_sec_ter_sku(product, single_row)
            product.reload
            product.save!
          end

          def import_product_name(product, single_row)
            if params[:use_sku_as_product_name] == true
              product.name = @helper.get_row_data(single_row, 'sku').strip
            elsif @helper.verify_single_item(single_row, 'product_name')
              product.name = @helper.get_row_data(single_row, 'product_name')
            else
              product.name = 'Product created from order import'
            end
          end

          def import_product_weight(product, single_row)
            product.weight = @helper.get_row_data(single_row, 'product_weight') if
            @helper.verify_single_item(single_row, 'product_weight')
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
            @helper.get_row_data(single_row, 'product_instructions') if
              @helper.verify_single_item(single_row, 'product_instructions')
          end

          def import_image(product, single_row, check_duplicacy = false)
            return unless @helper.verify_single_item(single_row, 'image')
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
            product_image.image = @helper.get_row_data(single_row, 'image')
            product.product_images << product_image
          end

          def duplicate_image?(product, single_row)
            product_images = product.product_images
            product_images.each do |single_image|
              return true if
                single_image.image == @helper.get_row_data(single_row, 'image')
            end
            false
          end

          def check_and_update_prod_sku(product_skus, order_increment_sku)
            product_sku = product_skus.where(sku: order_increment_sku).first
            if product_sku
              product_sku.sku = order_increment_sku + '-1'
              if params[:generate_barcode_from_sku] == true
                product = product_sku.product
                product.product_barcodes.last.delete
                push_barcode(product, product_sku.sku)
              end
              product_sku.save
            end
          end

          def import_product_data(product, single_row, order_increment_sku, unique_order_item)
            import_product_name(product, single_row)
            import_product_weight(product, single_row)
            import_product_sku(product, single_row, order_increment_sku, unique_order_item)
            import_product_barcode(product, single_row, order_increment_sku, unique_order_item)
            product.store_product_id = 0
            product.store_id = params[:store_id]
            product.spl_instructions_4_packer =
              import_product_instructions(single_row)
            import_image(product, single_row)
            import_product_category(product, single_row)
            if unique_order_item
              product.base_sku = @helper.get_row_data(single_row, 'sku').strip
            else
              import_sec_ter_sku(product, single_row)
              import_sec_ter_barcode(product, single_row)
            end
            product.save!
            product
          end

          def import_product_barcode(product, single_row, order_increment_sku, unique_order_item = false)
            if params[:generate_barcode_from_sku] == true
              push_barcode(product, @helper.get_sku(single_row, order_increment_sku, unique_order_item))
            elsif @helper.verify_single_item(single_row, 'barcode')
              barcode = @helper.get_row_data(single_row, 'barcode')
              if ProductBarcode.where(
                barcode: barcode.strip).empty?
                push_barcode(product, barcode)
              end
            end
          end

          def import_product_sku(product, single_row, order_increment_sku, unique_order_item = false)
            sku = ProductSku.new
            # sku.sku = single_row[mapping['sku'][:position]].strip
            sku.sku = @helper.get_sku(single_row, order_increment_sku, unique_order_item)
            product.product_skus << sku
          end
        end
      end
    end
  end
end
