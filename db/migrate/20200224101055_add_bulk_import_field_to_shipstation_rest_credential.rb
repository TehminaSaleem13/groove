class AddBulkImportFieldToShipstationRestCredential < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :bulk_import, :boolean, :default => false 
  end
end
