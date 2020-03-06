class AddQuickImportLastModifiedV2ToShipstationRest < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :quick_import_last_modified_v2, :datetime
  end
end
