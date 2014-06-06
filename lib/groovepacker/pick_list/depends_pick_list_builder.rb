module Groovepacker
	module PickList
		class DependsPickListBuilder < PickListBuilder
			def build(qty, product, pick_list, inventory_warehouse_id)
				single_pick_list = []
				individual_pick_list = []

				# check if sku is found or not, get index if found


			  # if sku is found, then single_pick_list = pick_list[index]['single']


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
				pick_list.push({
					"sku" => sku,
					"single" => single_pick_list,
				  "individual" => individual_pick_list})
				#else
				#pick_list[index]['single']= single_pick_list

				pick_list
			end
		end
	end
end


