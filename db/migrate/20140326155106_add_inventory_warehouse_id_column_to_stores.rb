class AddInventoryWarehouseIdColumnToStores < ActiveRecord::Migration
  def change
    add_column :stores, :inventory_warehouse_id, :integer, references: :inventory_warehouses
  end
end
