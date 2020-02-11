class AddTagImportOptionToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :tag_import_option, :boolean, default: false
  end
end
