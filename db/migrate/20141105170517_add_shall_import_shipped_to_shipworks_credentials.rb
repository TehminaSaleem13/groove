class AddShallImportShippedToShipworksCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipworks_credentials, :shall_import_shipped, :boolean, default: false
  end
end
