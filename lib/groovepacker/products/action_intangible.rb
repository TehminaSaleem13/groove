module Groovepacker
  module Products
    class ActionIntangible
      def update_intangibleness(tenant, params, intangible_setting_enabled, intangible_string)
        Apartment::Tenant.switch(tenant)
        intangible_strings = intangible_string.split(",")
        intangible_param_strings = params[:intangible_string].split(",")
        if params[:intangible_setting_enabled]
          if intangible_param_strings != intangible_strings || intangible_setting_enabled == false
            products = Product.all
            products.each do |product|
              intangible_strings.each do |string|
                if (product.name.start_with? (string)) || sku_starts_with_intangible_string(product, string)
                  product.is_intangible = false
                  product.save
                end
              end
            end
            products = Product.all
            products.each do |product|
              intangible_param_strings.each do |param_string|
                if (product.name.start_with? (param_string)) || sku_starts_with_intangible_string(product, param_string)
                  product.is_intangible = true
                  product.save
                end
              end
            end
          end
        else
          products = Product.all
          products.each do |product|
            intangible_param_strings.each do |string|
              # sku_starts_with_intangible_string(product,string)
              if (product.name.start_with? (string)) || sku_starts_with_intangible_string(product, string)
                product.is_intangible = false
                product.save
              end
            end
          end
        end
      end

      private

      def sku_starts_with_intangible_string(product, intangible_string)
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
