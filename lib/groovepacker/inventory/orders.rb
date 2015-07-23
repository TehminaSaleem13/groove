module Groovepacker
	module Inventory
		class Orders
			class << self
				include Groovepacker::Inventory::Helper
				def sell(order)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					order.order_items.each do |order_item|
						result &= process_sell_item(order_item)
					end
					result
				end

				def unsell(order)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					order.order_items.each do |order_item|
						result &= process_sell_item(order_item, -1)
					end
					result
				end

				def allocate(order, status_match = false)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					order.order_items.each do |order_item|
						result &= allocate_item(order_item, status_match)
					end
					result
				end

				def deallocate(order, status_match = false)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					order.order_items.each do |order_item|
						result &= deallocate_item(order_item, status_match)
					end
				end

				def item_update(order_item, initial_count, final_count)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					if order_item.is_inventory_allocated?
						if initial_count.nil?
							initial_count = 0
						end
						if final_count.nil?
							final_count = 0
						end
						difference = final_count - initial_count
						result &= do_allocate_item(order_item, difference)
					elsif order_item.is_inventory_unprocessed?
						# This condition means that the item is somehow still unprocessed, we'll process it.
						# since final qty will be used to allocate, we use that
						result &= allocate_item(order_item)
					end
					result
				end

				def allocate_item(order_item, status_match = false)
					unless inventory_tracking_enabled?
						return false
					end
					if order_item.is_inventory_allocated? || order_item.is_inventory_sold?
						return false
					end
					do_allocate_item(order_item, order_item.qty, OrderItem::ALLOCATED_INV_STATUS, status_match)
				end

				def deallocate_item(order_item, status_match = false)
					unless inventory_tracking_enabled?
						return false
					end
					unless order_item.is_inventory_allocated?
						return false
					end

					do_allocate_item(order_item, -order_item.qty, OrderItem::UNALLOCATED_INV_STATUS, status_match)
				end

				private

				def individual_sell(order_item, qty, warehouse_id = nil)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					order_item.product.base_product.product_kit_skuss.each do |kit_item|
						result &= update_sold_inventory(order_item, select_product_warehouse(kit_item.option_product, warehouse_id), qty * kit_item.qty)
					end
					result
				end

				def sell_item(order_item, qty, warehouse_id = nil)
					unless inventory_tracking_enabled?
						return false
					end
					result = true
					if order_item.product.base_product.should_scan_as_single_product?
						result &= update_sold_inventory(order_item, select_product_warehouse(order_item.product.base_product, warehouse_id), qty)
					elsif order_item.product.base_product.should_scan_as_individual_items?
						result &= individual_sell(order_item, qty, warehouse_id)
					end
					result
				end

				def process_sell_item(order_item, integer = 1)
					result = true
					multiplier = (integer*integer)/integer
					if (multiplier == 1 && !order_item.is_inventory_allocated?) || (multiplier == -1 && !order_item.is_inventory_sold?)
						return false
					end
					if is_depends_kit?(order_item) && order_item.kit_split
						split_depends_kit(order_item, multiplier*order_item.kit_split_qty)
						result &= sell_depends_kit(order_item, multiplier*order_item.kit_split_scanned_qty, multiplier*order_item.single_scanned_qty)
					else
						result &= sell_item(order_item, multiplier*order_item.qty, order_item.order.store.inventory_warehouse_id)
					end
					if multiplier == 1
						order_item.update_column(:inv_status, OrderItem::SOLD_INV_STATUS)
					else
						order_item.update_column(:inv_status, OrderItem::ALLOCATED_INV_STATUS)
					end
					result
				end

				def update_sold_inventory(order_item, product_warehouse, qty)
					unless inventory_tracking_enabled?
						return false
					end
					if product_warehouse.nil? || qty == 0
						return false
					end

					if qty > 0
						sold_inventory = SoldInventoryWarehouse.new
						sold_inventory.sold_qty = qty
						sold_inventory.product_inventory_warehouses = product_warehouse
						sold_inventory.order_item = order_item
						sold_inventory.sold_date = order_item.order.scanned_on
						sold_inventory.save
					else
						sold_inventories = SoldInventoryWarehouse.where(:order_item_id => order_item.id, :product_inventory_warehouses_id => product_warehouse.id)
						if sold_inventories.length > 0
							#destroy all sold inventories for the current order item
							# Not the ideal solution but this condition is only reached when
							# an order is moved from scanned to other states, all sold information would be removed anyway
							sold_inventories.each do |sold_inventory|
								sold_inventory.destroy
							end
						end
						if order_item.order.reallocate_inventory?
							product_warehouse.available_inv = product_warehouse.available_inv + qty
						end
					end

					product_warehouse.allocated_inv = product_warehouse.allocated_inv - qty
					product_warehouse.save
					true
				end

				def do_allocate_item(order_item, qty, status = OrderItem::ALLOCATED_INV_STATUS, status_match = false)
					unless inventory_tracking_enabled? && should_process_allocation?(order_item, status_match)
						return false
					end
					result = true
					result &= Groovepacker::Inventory::Products.allocate(order_item.product.base_product, qty, order_item.order.store.inventory_warehouse_id)
					#Set on hold here when needed
					if status != order_item.inv_status
						order_item.update_column(:inv_status,status)
					end
					result
				end

				def split_depends_kit(order_item, qty)
					# Negative sign deallocates
					result = do_allocate_item(order_item, -qty, OrderItem::ALLOCATED_INV_STATUS, true)
					if result
						result &= Groovepacker::Inventory::Products.individual_allocate(order_item.product.base_product, qty, order_item.order.store.inventory_warehouse_id)
					end
					result
				end

				def sell_depends_kit(order_item, split_scanned_qty, single_scanned_qty)
					result = individual_sell(order_item, split_scanned_qty, order_item.order.store.inventory_warehouse_id)
					if order_item.single_scanned_qty
						result &= sell_item(order_item, single_scanned_qty, order_item.order.store.inventory_warehouse_id)
					end

					result
				end

				def is_depends_kit?(order_item)
					!order_item.product.nil? && order_item.product.is_kit == 1 && order_item.product.kit_parsing == Product::DEPENDS_KIT_PARSING
				end

				def should_process_allocation?(order_item, status_match)
					(order_item.is_not_ghost? && (Order::ALLOCATE_STATUSES.include?(order_item.order.status) || status_match))
				end

			end
		end
	end
end
