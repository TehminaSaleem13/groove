class LimitPrimaryAndSecondaryLocationLength < ActiveRecord::Migration
  def up
    change_column :product_inventory_warehouses, :location_primary, :string, :limit => 50
    change_column :product_inventory_warehouses, :location_secondary, :string, :limit => 50
  end

  def down
    change_column :product_inventory_warehouses, :location_primary, :string
    change_column :product_inventory_warehouses, :location_secondary, :string
  end
end
