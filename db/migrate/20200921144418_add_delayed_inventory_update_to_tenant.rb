class AddDelayedInventoryUpdateToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :delayed_inventory_update, :boolean, default: false
  end
end
