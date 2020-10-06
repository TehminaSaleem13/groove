class AddInventoryWarehouseIdColumnToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :inventory_warehouse_id, :integer, references: :inventory_warehouses
  end
end
