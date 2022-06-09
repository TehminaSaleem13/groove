class AddInvTargetLevelToProductInventoryWarehouse < ActiveRecord::Migration[5.1]
  def change
    add_column :product_inventory_warehouses, :product_inv_target_level, :integer, default: 1
  end
end
