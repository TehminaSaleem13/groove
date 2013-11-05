class CreateProductInventoryWarehouses < ActiveRecord::Migration
  def change
    create_table :product_inventory_warehouses do |t|
      t.string :location
      t.integer :qty
      t.references :product

      t.timestamps
    end
    add_index :product_inventory_warehouses, :product_id
  end
end
