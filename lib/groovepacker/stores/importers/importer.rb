module Groovepacker
  module Stores
    module Importers
      class Importer
        def initialize(handler)
          self.handler = handler
        end

        def import
          {}
        end

        def import_single(hash)
          {}
        end

        def get_handler
          self.handler
        end

        def build_result
          {
            messages: [],
            previous_imported: 0,
            success_imported: 0,
            total_imported: 0,
            debug_messages: [],
            status: true
          }
        end

        # checks if product contains temp skus
        def contains_temp_skus(products)
          result = false
          products.each do |prod_item|
            if prod_item.product_skus.where("sku LIKE 'TSKU-%'").length > 0
              result = true
              break
            end
          end
          result
        end

        def get_product_with_temp_skus(products)
          result = nil
          products.each do |prod_item|
            if prod_item.product_skus.where("sku LIKE 'TSKU-%'").length > 0
              result = prod_item
              break
            end
          end
          result
        end

        def initialize_import_item
          @import_item.update_attributes( :current_increment_id => '', 
                                            :success_imported => 0, 
                                            :previous_imported => 0, 
                                            :updated_orders_import => 0,
                                            :current_order_items => -1, 
                                            :current_order_imported_item => -1, 
                                            :to_import => @result[:total_imported])
        end
        protected
        attr_accessor :handler


      end
    end
  end
end
