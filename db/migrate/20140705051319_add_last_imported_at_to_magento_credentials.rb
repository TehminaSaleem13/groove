class AddLastImportedAtToMagentoCredentials < ActiveRecord::Migration[5.1]
  def change
  	add_column :magento_credentials, :last_imported_at, :datetime
  end
end
