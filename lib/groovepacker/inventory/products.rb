module Groovepacker
	module Inventory
		class Products
			class << self
				include Groovepacker::Inventory::Helper
				def allocate(product, qty, warehouse_id = nil)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					if product.base_product.should_scan_as_single_product?
						result &= do_allocate(select_product_warehouse(product, warehouse_id), qty)
					elsif product.base_product.should_scan_as_individual_items?
						result &= individual_allocate(product, qty, warehouse_id)
					end
					result
				end

				def deallocate(product, qty, warehouse_id = nil)
					allocate(product, -qty, warehouse_id)
				end

				def individual_allocate(kit, qty, warehouse_id = nil)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					kit.product_kit_skuss.each do |kit_item|
						result &= do_allocate(select_product_warehouse(kit_item.option_product, warehouse_id), qty * kit_item.qty)
					end
					result
				end

				private

				def do_allocate(product_warehouse, qty)
					unless inventory_tracking_enabled?
						return false
					end
					if product_warehouse.nil? || qty == 0
						return false
					end
					product_warehouse.available_inv = product_warehouse.available_inv - qty
					product_warehouse.allocated_inv = product_warehouse.allocated_inv + qty
					product_warehouse.save
					# When implementing on hold due to inventory, return false if qty > available inv

					true
				end

			end
		end
	end
end
