class AddColumnsToShipworksCredential < ActiveRecord::Migration
  def change
    add_column :shipworks_credentials, :shall_import_in_process, :boolean, default: false
    add_column :shipworks_credentials, :shall_import_new_order, :boolean, default: false
    add_column :shipworks_credentials, :shall_import_not_shipped, :boolean, default: false
  end
end
