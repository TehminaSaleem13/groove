module Groovepacker
  module Products
    class Aliasing < Groovepacker::Products::Base

      def set_alias
        @product_orig = Product.find(@params[:id])
        skus_len = @product_orig.product_skus.all.length
        barcodes_len = @product_orig.product_barcodes.all.length
        @product_aliases = Product.find_all_by_id(@params[:product_alias_ids])
        if @product_aliases.length < 1
          @result['status'] = false
          @result['messages'].push('No products found to alias')
          return @result
        end

        @product_aliases.each do |product_alias|
          do_aliasing(product_alias, skus_len, barcodes_len)
        end
        @product_orig.update_product_status
        return @result
      end

      private
        def do_aliasing(product_alias, skus_len, barcodes_len)
          #all SKUs of the alias will be copied. dont use product_alias.product_skus
          copy_skus_of_alias(product_alias, skus_len)
          #all Borcodes of the alias will be copied. dont use product_alias.product_skus
          copy_barcodes_of_alias(product_alias, barcodes_len)
          #update order items of aliased products to original products
          update_order_items_of_aliased_products(product_alias)
          #update kit. Replace the alias product with original product
          update_productkitsku_to_orig_product(product_alias)
          
          #Ensure all inventory data is copied over
          #The code has been modified keeping in mind that we use only one warehouse per product as of now.
          ProductInventoryWarehouses.copy_inventory_data_for_aliasing(product_alias, @product_orig)
          
          #destroy the aliased object
          return if product_alias.destroy
          #status will be updated to false if not able to destroy the product alias
          @result['status'] &= false
          @result['messages'].push('Error deleting the product alias id:'+product_alias.id)
        end

        def copy_skus_of_alias(product_alias, skus_len)
          @product_skus = ProductSku.where(:product_id => product_alias.id)
          copy_sku_or_barocdes_of_aliased_product(@product_skus, skus_len)
        end

        def copy_barcodes_of_alias(product_alias, barcodes_len)
          @product_barcodes = ProductBarcode.where(:product_id => product_alias.id)
          copy_sku_or_barocdes_of_aliased_product(@product_barcodes, barcodes_len)
        end

        def copy_sku_or_barocdes_of_aliased_product(objects, objects_len)
          objects.each do |object|
            object.product_id = @product_orig.id
            object.order = objects_len
            objects_len+=1
            set_status_and_msg('Barcode', object) unless object.save
          end
        end

        def update_order_items_of_aliased_products(product_alias)
          @order_items = OrderItem.where(:product_id => product_alias.id)
          @order_items.each do |order_item|
            order_item.product_id = @product_orig.id
            set_status_and_msg('order item', order_item) unless order_item.save
          end
        end

        def update_productkitsku_to_orig_product(product_alias)
          product_kit_skus = ProductKitSkus.where(option_product_id: product_alias.id)
          product_kit_skus.each do |product_kit_sku|
            product_kit_sku.option_product_id = @product_orig.id
            unless product_kit_sku.save
              @result['status'] &= false
              @result['messages'].push('Error replacing aliased product in the kits')
            end
          end
        end

        def set_status_and_msg(obj_class, alias_obj)
          @result['status'] &= false
          @result['messages'].push("Error saving #{obj_class} for #{obj_class} id #{alias_obj.id}")
        end

    end
  end
end
