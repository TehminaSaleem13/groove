class AddBulkImportFieldToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :bulk_import, :boolean, :default => false 
  end
end
