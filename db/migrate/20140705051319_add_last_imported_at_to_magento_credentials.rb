class AddLastImportedAtToMagentoCredentials < ActiveRecord::Migration
  def change
  	add_column :magento_credentials, :last_imported_at, :datetime
  end
end
