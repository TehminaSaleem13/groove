class AddInventoryAutoAllocationToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :inventory_auto_allocation, :boolean, :default => false
  end
end
