class FixFaultyOrdersAndRemoveDuplicateSkus < ActiveRecord::Migration
  def up

  	ProductSku.all.each do |sku|
  		dup_skus = ProductSku.where(:sku => sku.sku)
  		active_product_id = 0
  		active_product_found = false
  	
  		if dup_skus.length != 1 && dup_skus.length > 0
  	
  			dup_skus.each do |product_sku|
  				#find active products to keep 
  				if product_sku.product.status == 'active'
  					active_product_id = product_sku.product_id
  					active_product_found = true
  					break
  				end
  			end
  	
  			# if no active product found keep the first occurence
			  if !active_product_found
					active_product_id = dup_skus.first.product_id
					active_product_found = true
				end

				dup_skus.each do |product_sku|
					if product_sku.product_id != active_product_id
						order_items = OrderItem.where(:product_id=>product_sku.product_id)
						order_items.each do |order_item|
							order_item.product_id = active_product_id
							order_item.save
						end
						product_sku.product.destroy
					end
				end
  	
  		end
  	end
  	#get all duplicate skus
  	#decide which sku product to keep
  	#for other sku's mark order items to be associated with the correct product and then delete the skus
  end

  def down
  end
end
