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
            result &= allocate(kit_item.option_product, qty * kit_item.qty,warehouse_id)
          end
          result
        end

        def kit_item_inv_change(kit_item, difference)
          unless inventory_tracking_enabled?
            return false
          end
          order_items = OrderItem.where(:product_id=>kit_item.product_id)
          order_items.each do |order_item|
            Groovepacker::Inventory::Orders.kit_item_process(order_item,kit_item,difference)
          end
        end

        def sell(product, qty, warehouse_id = nil,update_available = false, update_allocated = false)
          unless inventory_tracking_enabled?
            return false
          end
          result = true
          if product.should_scan_as_single_product?
            result &= do_sell(select_product_warehouse(product, warehouse_id), qty, update_available, update_allocated)
          elsif product.should_scan_as_individual_items?
            result &= individual_sell(product, qty, warehouse_id, update_available, update_allocated)
          end
          result
        end

        private

        def individual_sell(kit, qty, warehouse_id = nil, update_available = false, update_allocated = false)
          unless inventory_tracking_enabled?
            return false
          end
          result = true
          kit.product_kit_skuss.each do |kit_item|
            result &= sell(kit_item.option_product, qty * kit_item.qty, warehouse_id, update_available, update_allocated)
          end
          result
        end



        def do_sell(product_warehouse, qty, update_available = false, update_allocated = false)
          unless inventory_tracking_enabled?
            return false
          end
          if product_warehouse.nil? || qty == 0
            return false
          end


          if update_available
            product_warehouse.available_inv = product_warehouse.available_inv + qty
          end
          if update_allocated
            product_warehouse.allocated_inv = product_warehouse.allocated_inv - qty
          end
          product_warehouse.sold_inv = product_warehouse.sold_inv + qty
          product_warehouse.save
          true
        end

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
