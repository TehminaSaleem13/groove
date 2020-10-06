class AddRemoveOrderItemToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :remove_order_items, :boolean, :default => false
  end
end
