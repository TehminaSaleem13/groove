module Groovepacker
  module Stores
    module Importers
      module CSV
        class KitsImporter

          # This is the longer, slower import for now, we will optimize it later when we have more time on our hands
          def import(params, final_record, mapping, bulk_action_id)
            result = Hash.new
            result['status'] = true
            result['messages'] = []
            #check_length = check_after_every(final_record.length)
            # success = 0
            # success_imported = 0
            # success_updated = 0
            file_kit_skus = []
            update_status_products = []
            bulk_action = GrooveBulkActions.find(bulk_action_id)
            begin

              bulk_action.total = final_record.length
              bulk_action.completed = 0
              bulk_action.status = 'in_progress'
              bulk_action.save
              final_record.each_with_index do |single_row, index|
                should_import = false
                bulk_action.reload
                if bulk_action.cancel?
                  bulk_action.status = 'cancelled'
                  bulk_action.save
                  return true
                end
                if not_blank?('kit_sku', single_row, mapping)
                  kit_sku = single_row[mapping['kit_sku'][:position]]
                  bulk_action.current = kit_sku
                  bulk_action.completed = index
                  bulk_action.save
                  if file_kit_skus.include?(kit_sku)
                    should_import = true
                  else
                    # Check if kit sku is a product
                    existing_sku = ProductSku.where(:sku => kit_sku)
                    if existing_sku.length == 0
                      should_import = true
                      file_kit_skus << kit_sku
                      # else
                      #   #check if existing product is a product
                      #   if existing_sku.product.is_kit != 1
                      #     should_import = true
                      #   end
                    end
                  end
                  if should_import
                    matching_sku = ProductSku.where(:sku => kit_sku)
                    if matching_sku.length == 0
                      kit_product = Product.new
                      kit_product_sku = ProductSku.new
                      kit_product_sku.sku = kit_sku
                      kit_product_sku.order = 0
                      kit_product.product_skus << kit_product_sku
                      # Add barcode only when creating a new kit, this solves having to check every time.
                      if not_blank?('kit_barcode', single_row, mapping)
                        kit_product_barcode = ProductBarcode.new
                        kit_product_barcode.barcode = single_row[mapping['kit_barcode'][:position]]
                        kit_product.product_barcodes << kit_product_barcode
                      end
                    else
                      kit_product = Product.find(matching_sku.first.product_id)
                    end
                    kit_product.store_id = params[:store_id]
                    kit_product.store_product_id = 'csv_import_'+params[:store_id].to_s+'_'+SecureRandom.uuid+'_'+kit_sku
                    kit_product.is_kit = 1
                    kit_product.kit_parsing = Product::SINGLE_KIT_PARSING
                    if not_blank?('kit_name', single_row, mapping)
                      kit_product.name = single_row[mapping['kit_name'][:position]]
                    end
                    if kit_product.name.blank?
                      kit_product.name = 'Kit imported from csv Kit import'
                    end
                    kit_product.save

                    #import product
                    if not_blank?('part_sku', single_row, mapping)
                      product_sku = single_row[mapping['part_sku'][:position]]
                      list_product_sku = ProductSku.where(:sku => product_sku)
                      if list_product_sku.length == 0
                        single_import_product = Product.new
                        single_import_product_sku = ProductSku.new
                        single_import_product_sku.sku = product_sku
                        single_import_product.product_skus << single_import_product_sku
                        if not_blank?('part_barcode', single_row, mapping)
                          single_import_product_barcode = ProductBarcode.new
                          single_import_product_barcode.barcode = single_row[mapping['part_barcode'][:position]]
                          single_import_product.product_barcodes << single_import_product_barcode
                        end
                      else
                        single_import_product = Product.find(list_product_sku.first.product_id)
                      end
                      single_import_product.store_id = params[:store_id]
                      single_import_product.store_product_id = 'csv_import_'+params[:store_id].to_s+'_'+SecureRandom.uuid+'_'+product_sku
                      if not_blank?('part_name', single_row, mapping)
                        single_import_product.name = single_row[mapping['part_name'][:position]]
                      end
                      if single_import_product.name.blank?
                        single_import_product.name = 'Product imported from csv Kit import'
                      end
                      single_import_product.save
                      update_status_products << single_import_product

                      if not_blank?('part_qty', single_row, mapping)
                        product_kit_part_sku = ProductKitSkus.find_or_create_by_product_id_and_option_product_id(kit_product.id, single_import_product.id)
                        product_kit_part_sku.qty = single_row[mapping['part_qty'][:position]]
                        product_kit_part_sku.save
                      end
                    end

                  end

                end

              end
              update_status_products.each do |product|
                product.update_product_status
              end

              bulk_action.status='completed'
              bulk_action.save
            rescue Exception => e
              bulk_action.status='failed'
              bulk_action.messages=['Some error occured', e.message]
              bulk_action.save
            end
          end

          def not_blank?(type, single_row, mapping)
            !mapping[type].nil? && mapping[type][:position] >=0 && !single_row[mapping[type][:position]].blank?
          end

          def check_after_every(length)
            if length <= 1000
              return 5
            end
            if length <= 5000
              return 25
            end
            if length <= 10000
              return 50
            end
            return 100
          end

        end
      end
    end
  end
end
