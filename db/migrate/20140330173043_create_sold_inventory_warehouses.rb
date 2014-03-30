class CreateSoldInventoryWarehouses < ActiveRecord::Migration
  def change
    create_table :sold_inventory_warehouses do |t|
      t.integer :product_inventory_warehouses_id, references: :product_inventory_warehousess
      t.integer :sold_qty
      t.timestamp :sold_date

      t.timestamps
    end
  end
end
