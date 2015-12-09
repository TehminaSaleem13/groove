class AddLastImportedAtColumnToMagentoRestCredential < ActiveRecord::Migration
  def change
    add_column :magento_rest_credentials, :last_imported_at, :datetime
  end
end
