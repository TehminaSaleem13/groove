class AddColumnToShipworkCredential < ActiveRecord::Migration
  def change
  	add_column :shipworks_credentials, :shall_import_ignore_local, :boolean, default: false
  end
end
