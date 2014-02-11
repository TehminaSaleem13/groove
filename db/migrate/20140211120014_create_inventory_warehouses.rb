class CreateInventoryWarehouses < ActiveRecord::Migration
  def change
    create_table :inventory_warehouses do |t|
      t.string :name, :null=>false
      t.string :location

      t.timestamps
    end
  end
end
