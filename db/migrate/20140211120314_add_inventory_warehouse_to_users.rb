class AddInventoryWarehouseToUsers < ActiveRecord::Migration
  def change
    add_column :users, :inventory_warehouse_id, :integer, references: :inventory_warehouses
    add_index :users, :inventory_warehouse_id
  end
end
