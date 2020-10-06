class AddLastImportStoreToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :last_import_store_type, :string, :default => nil
  end
end
