module Groovepacker
  module Products
    class Aliasing < Groovepacker::Products::Base

      def set_alias
        @product_orig = Product.find(@params[:id])
        skus_len = @product_orig.product_skus.all.length
        barcodes_len = @product_orig.product_barcodes.all.length
        @product_aliases = Product.find_all_by_id(@params[:product_alias_ids])
        if @product_aliases.length > 0
          @product_aliases.each do |product_alias|
            #all SKUs of the alias will be copied. dont use product_alias.product_skus
            @product_skus = ProductSku.where(:product_id => product_alias.id)
            @product_skus.each do |alias_sku|
              alias_sku.product_id = @product_orig.id
              alias_sku.order = skus_len
              skus_len+=1
              if !alias_sku.save
                @result['status'] &= false
                @result['messages'].push('Error saving Sku for sku id'+alias_sku.id.to_s)
              end
            end

            @product_barcodes = ProductBarcode.where(:product_id => product_alias.id)
            @product_barcodes.each do |alias_barcode|
              alias_barcode.product_id = @product_orig.id
              alias_barcode.order = barcodes_len
              barcodes_len+=1
              if !alias_barcode.save
                @result['status'] &= false
                @result['messages'].push('Error saving Barcode for barcode id'+alias_barcode.id)
              end
            end

            #update order items of aliased products to original products
            @order_items = OrderItem.where(:product_id => product_alias.id)
            @order_items.each do |order_item|
              order_item.product_id = @product_orig.id
              if !order_item.save
                @result['status'] &= false
                @result['messages'].push('Error saving order item with id'+order_item.id)
              end
            end

            #update kit. Replace the alias product with original product
            product_kit_skus = ProductKitSkus.where(option_product_id: product_alias.id)
            product_kit_skus.each do |product_kit_sku|
              product_kit_sku.option_product_id = @product_orig.id
              unless product_kit_sku.save
                @result['status'] &= false
                @result['messages'].push('Error replacing aliased product in the kits')
              end
            end

            #Ensure all inventory data is copied over
            #The code has been modified keeping in mind that we use only one warehouse per product as of now.
            orig_product_inv_wh = @product_orig.primary_warehouse
            aliased_inventory = product_alias.primary_warehouse
            if orig_product_inv_wh.nil?
              orig_product_inv_wh = ProductInventoryWarehouses.new
              orig_product_inv_wh.inventory_warehouse_id = aliased_inventory.inventory_warehouse_id
              orig_product_inv_wh.product_id = @product_orig.id
              orig_product_inv_wh.quantity_on_hand = aliased_inventory.quantity_on_hand
              orig_product_inv_wh.save
            end
            if orig_product_inv_wh.product.is_kit == 0
              #copy over the qoh of original as QOH of original should not change in aliasing
              orig_product_qoh = orig_product_inv_wh.quantity_on_hand
              orig_product_inv_wh.allocated_inv = orig_product_inv_wh.allocated_inv + aliased_inventory.allocated_inv
              
              orig_product_inv_wh.sold_inv = orig_product_inv_wh.sold_inv + aliased_inventory.sold_inv
              orig_product_inv_wh.quantity_on_hand = orig_product_qoh
              orig_product_inv_wh.save
            else
              orig_product_inv_wh.product.product_kit_skuss.each do |kit_sku|
                kit_option_product_wh = kit_sku.option_product.primary_warehouse
                unless kit_option_product_wh.nil?
                  orig_kit_product_qoh = kit_option_product_wh.quantity_on_hand
                  kit_option_product_wh.allocated_inv = kit_option_product_wh.allocated_inv + (kit_sku.qty * aliased_inventory.allocated_inv)
            
                  kit_option_product_wh.sold_inv = kit_option_product_wh.sold_inv + (kit_sku.qty * aliased_inventory.sold_inv)
                  kit_option_product_wh.quantity_on_hand = orig_kit_product_qoh
                  kit_option_product_wh.save
                end 
              end
            end
            aliased_inventory.reload

            #destroy the aliased object
            if !product_alias.destroy
              @result['status'] &= false
              @result['messages'].push('Error deleting the product alias id:'+product_alias.id)
            end
          end
          @product_orig.update_product_status
        else
          @result['status'] = false
          @result['messages'].push('No products found to alias')
        end
        return @result
      end

      private
        

    end
  end
end
