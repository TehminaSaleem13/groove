class AddQuickImportLastModifiedToShipstationRest < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :quick_import_last_modified, :datetime
  end
end
