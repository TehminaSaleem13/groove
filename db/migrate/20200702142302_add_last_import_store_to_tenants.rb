class AddLastImportStoreToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :last_import_store_type, :string, :default => nil
  end
end
