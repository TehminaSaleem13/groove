class AddColumnsToProductInventoryWarehousess < ActiveRecord::Migration[5.1]
  def change
    add_column :product_inventory_warehouses, :available_inv, :integer, :default =>0, :null=> false
    add_column :product_inventory_warehouses, :allocated_inv, :integer, :default =>0, :null=> false
  end
end
