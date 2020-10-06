class AddSoldInvToProductInventoryWarehouse < ActiveRecord::Migration[5.1]
  def change
    add_column :product_inventory_warehouses, :sold_inv, :integer, :default => 0
  end
end
