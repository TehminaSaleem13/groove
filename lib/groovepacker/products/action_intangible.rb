module Groovepacker
  module Products
    class ActionIntangible
      def update_intangibleness(tenant,params,intangible_setting_enabled, intangible_string)
        Apartment::Tenant.switch(tenant)

        if params[:intangible_setting_enabled]
          if params[:intangible_string] != intangible_string || intangible_setting_enabled == false
            products = Product.where(:is_intangible=>true)
            products.each do |product|
              product.is_intangible = false
              product.save
            end
            products = Product.all
            products.each do |product|
              if product.name.start_with? (params[:intangible_string]) || sku_starts_with_intangible_string(product,params[:intangible_string])
                product.is_intangible = true
                product.save
              end
            end
          end
        else
          products = Product.where(:is_intangible=>true)
          products.each do |product|
            product.is_intangible = false
            product.save
          end
        end
      end

      def sku_starts_with_intangible_string(product,intangible_string)
        product_skus = product.product_skus
        intangible = false
        product_skus.each do |product_sku|
          if product_sku.sku.start_with? (intangible_string)
            intangible = true
            break
          end
        end
        return intangible
      end
    end
  end
end
