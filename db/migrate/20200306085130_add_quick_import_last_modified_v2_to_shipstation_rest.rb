class AddQuickImportLastModifiedV2ToShipstationRest < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :quick_import_last_modified_v2, :datetime unless column_exists? :shipstation_rest_credentials, :quick_import_last_modified_v2
  end
end
