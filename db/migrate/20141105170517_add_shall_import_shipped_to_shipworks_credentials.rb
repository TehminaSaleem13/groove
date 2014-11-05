class AddShallImportShippedToShipworksCredentials < ActiveRecord::Migration
  def change
    add_column :shipworks_credentials, :shall_import_shipped, :boolean, default: false
  end
end
