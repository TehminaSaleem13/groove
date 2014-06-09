module Groovepacker
	module PickList
		class DependsPickListBuilder < PickListBuilder
			def build(qty, product, pick_list, inventory_warehouse_id)
				single_pick_list = []
				individual_pick_list = []
				index = 0
				product_skus = product.product_skus
				sku_found = false
				# check if sku is found or not, get index if found
				if !product_skus.first.nil?
		      sku = product_skus.first.sku
		      if pick_list.length > 0
		        pick_list.each do |item|
		          if item['sku']== sku
		          	sku_found = true
		          	index = pick_list.index(item)
			  				# if sku is found, then single_pick_list = pick_list[index]['single']
			  				single_pick_list = pick_list[index]['single']
			  				individual_pick_list = pick_list[index]['individual']
			  				break
			  			end
			  		end
			  	end
			  end
			  		
				single_pick_list_builder = SinglePickListBuilder.new
				single_pick_list = single_pick_list_builder.build(
					qty,
					product, 
					single_pick_list, 
					inventory_warehouse_id) 
				
				individual_pick_list_builder = IndividualPickListBuilder.new
				individual_pick_list = individual_pick_list_builder.build(
					qty,
					product, 
					individual_pick_list, 
					inventory_warehouse_id)
				#if sku is not found
	  		if !sku_found
					pick_list.push({
						"sku" => sku,
						"single" => single_pick_list,
					  "individual" => individual_pick_list})
				else
					pick_list[index]['single']= single_pick_list
					pick_list[index]['individual']= individual_pick_list
	  		end	

				pick_list
			end
		end
	end
end


