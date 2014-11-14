class AddTertiaryLocationToProductInventoryWarehouses < ActiveRecord::Migration
  def change
    add_column :product_inventory_warehouses, :location_tertiary, :string, :limit => 50
  end
end
