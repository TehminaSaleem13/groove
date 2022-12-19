# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module CSV
        class KitsImporter < CsvBaseImporter
          # This is the longer, slower import for now, we will optimize it later when we have more time on our hands
          def import
            build_initial
            # result = self.build_result
            # check_length = check_after_every(self.final_record.length)
            # success = 0
            # success_imported = 0
            # success_updated = 0
            # @file_kit_skus = []
            # @update_status_products = []
            # here import_action is the bulk_action_id
            # bulk_action = GrooveBulkActions.find(self.import_action)
            begin
              initiate_bulk_action
              final_record.each_with_index do |single_row, index|
                should_import = false
                return true if bulk_action_cancelled == true

                next unless not_blank?('kit_sku', single_row)

                kit_sku = single_row[mapping['kit_sku'][:position]].strip
                @bulk_action.current = kit_sku
                @bulk_action.completed = index
                @bulk_action.save
                if @file_kit_skus.include?(kit_sku)
                  should_import = true
                else
                  # Check if kit sku is a product
                  existing_sku = ProductSku.where(sku: kit_sku)
                  if existing_sku.empty?
                    should_import = true
                    @file_kit_skus << kit_sku
                  elsif existing_sku.first.product.is_kit != 1
                    should_import = true
                    @file_kit_skus << kit_sku
                  end
                end
                # if should_import
                #   import_kit(single_row, kit_sku)
                # end
                import_kit(single_row, kit_sku)
              end
              @update_status_products.each(&:update_product_status)
              update_orders_status
              @bulk_action.status = 'completed'
              @bulk_action.save
            rescue Exception => e
              @bulk_action.status = 'failed'
              @bulk_action.messages = ['Some error occured', e.message]
              @bulk_action.save
            end
          end

          def build_initial
            @result = build_result
            @file_kit_skus = []
            @update_status_products = []
            @bulk_action = GrooveBulkActions.find(import_action)
          end

          def initiate_bulk_action
            @bulk_action.total = final_record.length
            @bulk_action.completed = 0
            @bulk_action.status = 'in_progress'
            @bulk_action.save
          end

          def bulk_action_cancelled
            @bulk_action.reload
            if @bulk_action.cancel?
              @bulk_action.status = 'cancelled'
              @bulk_action.save
              return true
            end
          end

          def import_kit(single_row, kit_sku)
            matching_sku = ProductSku.where(sku: kit_sku)
            if matching_sku.empty?
              kit_product = Product.new
              kit_product_sku = ProductSku.new
              kit_product_sku.sku = kit_sku
              kit_product_sku.order = 0
              kit_product.product_skus << kit_product_sku
            else
              kit_product = Product.find(matching_sku.first.product_id)
            end
            if not_blank?('kit_barcode', single_row)
              kit_product_barcode = import_barcode('kit_barcode', single_row)
              kit_product.product_barcodes << kit_product_barcode
            end
            kit_product.store_id = params[:store_id]
            kit_product.store_product_id = 'csv_import_' + params[:store_id].to_s + '_' + SecureRandom.uuid + '_' + kit_sku
            kit_product.is_kit = 1
            kit_product.kit_parsing = apply_kit_parsing(single_row, kit_product)
            kit_product.name = import_name('kit_name', single_row, kit_product)
            kit_product.save

            kit_product.add_product_activity('Product Import', kit_product.store.try(:name).to_s) if kit_product_sku

            # import product
            import_kit_products(single_row, kit_product) if not_blank?('part_sku', single_row)
          end

          def apply_kit_parsing(single_row, _kit_product)
            if not_blank?('scan_option', single_row)
              option = single_row[mapping['scan_option'][:position]].to_s
              case option
              when '2'
                return Product::INDIVIDUAL_KIT_PARSING
              when '3'
                return Product::DEPENDS_KIT_PARSING
              else
                return Product::SINGLE_KIT_PARSING
              end
            else
              Product::SINGLE_KIT_PARSING
            end
          end

          def import_barcode(barcode, single_row)
            product_barcode = ProductBarcode.find_or_create_by(barcode: single_row[mapping[barcode][:position]].strip)

            product_barcode
          end

          def import_name(name, single_row, product)
            product.name = single_row[mapping[name][:position]] if not_blank?(name, single_row)
            if product.name.blank?
              product.name = (name == 'kit_name' ? 'Kit' : 'Product') + ' imported from csv Kit import'
            end

            product.name
          end

          def import_kit_products(single_row, kit_product)
            product_sku = single_row[mapping['part_sku'][:position]].strip
            list_product_sku = ProductSku.where(sku: product_sku)
            if list_product_sku.empty?
              single_import_product = Product.new
              single_import_product_sku = ProductSku.new
              single_import_product_sku.sku = product_sku
              single_import_product.product_skus << single_import_product_sku
            else
              single_import_product = Product.find(list_product_sku.first.product_id)
            end
            if not_blank?('part_barcode', single_row)
              single_import_product_barcode = import_barcode('part_barcode', single_row)
              single_import_product.product_barcodes << single_import_product_barcode
            end
            single_import_product.store_id = params[:store_id]
            single_import_product.store_product_id = 'csv_import_' + params[:store_id].to_s + '_' + SecureRandom.uuid + '_' + product_sku
            single_import_product.name = import_name('part_name', single_row, single_import_product)
            single_import_product.save
            @update_status_products << single_import_product

            if not_blank?('part_qty', single_row)
              product_kit_part_sku = ProductKitSkus.find_or_create_by(product_id: kit_product.id, option_product_id: single_import_product.id)
              product_kit_part_sku.qty = single_row[mapping['part_qty'][:position]]
              product_kit_part_sku.packing_order = single_row[mapping['kit_part_scanning_sequence'][:position]].to_i if not_blank?('kit_part_scanning_sequence', single_row) && single_row[mapping['kit_part_scanning_sequence'][:position]].to_i != 0
              product_kit_part_sku.save
            end
          end

          def not_blank?(type, single_row)
            !mapping[type].nil? && mapping[type][:position] >= 0 && !single_row[mapping[type][:position]].blank?
          end

          def check_after_every(length)
            return 5 if length <= 1000
            return 25 if length <= 5000
            return 50 if length <= 10_000

            100
          end
        end
      end
    end
  end
end
