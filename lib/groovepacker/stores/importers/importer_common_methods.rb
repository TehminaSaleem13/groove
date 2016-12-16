module Groovepacker
  module Stores
    module Importers
      module ImporterCommonMethods
		
		def find_create_product(r_product)
          if r_product["sku"].blank?
            # if sku is nil or empty
            product = create_product_with_temp_sku(r_product)
          elsif ProductSku.where(sku: r_product["sku"]).length == 0
            # if non-nil sku is not found
            product = create_new_product(r_product, r_product["sku"])
          else
            product = ProductSku.where(sku: r_product["sku"]).first.product
          end
          make_product_intangible(product)
          product.save
          return product
		end        

        def create_product_with_temp_sku(r_product)
          product_is_nil = Product.find_by_name(r_product["name"]).nil?
          # if sku is nil or empty
          if product_is_nil
            # and if product is not found by name then create the product
            product = create_new_product(r_product, ProductSku.get_temp_sku) #this method is defined in respective importer
          else
            # product exists add temp sku if it does not exist
            product = add_sku_for_existing_product(r_product)
          end
          return product
        end

        def add_sku_for_existing_product(r_product)
          products = Product.where(name: r_product["name"])
          unless contains_temp_skus(products)
            product = create_new_product(r_product, ProductSku.get_temp_sku) #this method is defined in respective importer
          else
            product = get_product_with_temp_skus(products)
          end
          return product
        end


      end
    end
  end
end
