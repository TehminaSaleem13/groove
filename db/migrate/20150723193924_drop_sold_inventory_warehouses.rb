class DropSoldInventoryWarehouses < ActiveRecord::Migration
  def up
    drop_table :sold_inventory_warehouses
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
