class AddDisplayOriginStoreNameToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :display_origin_store_name, :boolean, default: false
  end
end
