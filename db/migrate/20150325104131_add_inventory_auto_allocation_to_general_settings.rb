class AddInventoryAutoAllocationToGeneralSettings < ActiveRecord::Migration
  def change
  	add_column :general_settings, :inventory_auto_allocation, :boolean, :default => false
  end
end
