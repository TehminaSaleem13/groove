class AddShallImportNoStatusToShipworksCredentials < ActiveRecord::Migration
  def change
    add_column :shipworks_credentials, :shall_import_no_status, :boolean, default: false
  end
end
