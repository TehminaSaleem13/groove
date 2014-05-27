module StoreSettingsHelper
	def get_default_warehouse_id
		inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
		if !inventory_warehouses.nil?
			inventory_warehouse = inventory_warehouses.first
			default_warehouse_id = inventory_warehouse.id
			puts "default_warehouse_id"
			puts default_warehouse_id
			default_warehouse_id
		end
	end
	def get_default_warehouse_name
		inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
		if !inventory_warehouses.nil?
			inventory_warehouse = inventory_warehouses.first
			default_warehouse_name = inventory_warehouse.name
			puts "default_warehouse_name"
			puts default_warehouse_name
			default_warehouse_name
		end
	end
end
