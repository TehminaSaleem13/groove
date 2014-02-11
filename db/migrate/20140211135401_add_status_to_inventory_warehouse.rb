class AddStatusToInventoryWarehouse < ActiveRecord::Migration
  def change
    add_column :inventory_warehouses, :status, :string, :default=>'inactive'
  end
end
