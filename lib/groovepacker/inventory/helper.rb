module Groovepacker
	module Inventory
		module Helper
			def inventory_tracking_enabled?
				# Threads leak :( And this needs tenant wise setting in the same process,
				# We'll have to come up with a better solution later
				#
				# if Thread.current[:inventory_tracking_enabled].nil?
				# 	Thread.current[:inventory_tracking_enabled] = false
				# 	general_setting = GeneralSetting.all.first
				# 	unless general_setting.nil?
				# 		Thread.current[:inventory_tracking_enabled] = general_setting.inventory_tracking?
				# 	end
				# end
				# Thread.current[:inventory_tracking_enabled]

				GeneralSetting.all.first.inventory_tracking?
			end

			def hold_orders_due_to_inventory?
				# if Thread.current[:hold_orders_due_to_inventory].nil?
				# 	Thread.current[:hold_orders_due_to_inventory] = false
				# 	general_setting = GeneralSetting.all.first
				# 	unless general_setting.nil?
				# 		Thread.current[:hold_orders_due_to_inventory] = general_setting.hold_orders_due_to_inventory? if self.inventory_tracking_enabled?
				# 	end
				# end
        #
				# Thread.current[:hold_orders_due_to_inventory]
				false
			end

			def select_product_warehouse(product, warehouse_id)
				if warehouse_id.nil?
					warehouse = product.base_product.primary_warehouse
				else
					warehouse = ProductInventoryWarehouses.find_by_inventory_warehouse_id_and_product_id(warehouse_id, product.base_product.id)
				end
				warehouse
			end
		end
	end
end
