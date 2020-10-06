class AddStatusToInventoryWarehouse < ActiveRecord::Migration[5.1]
  def change
    add_column :inventory_warehouses, :status, :string, :default=>'inactive'
  end
end
