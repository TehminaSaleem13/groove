class AddQuickImportLastModifiedToShipstationRest < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :quick_import_last_modified, :datetime
  end
end
