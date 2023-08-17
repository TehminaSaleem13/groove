class AddShowOriginatingStoreIdToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :show_originating_store_id, :boolean, default: false
  end
end
