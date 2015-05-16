class AddColumnsToShipstationRestCredentials < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :shall_import_customer_notes, :boolean, default: false
    add_column :shipstation_rest_credentials, :shall_import_internal_notes, :boolean, default: false
  end
end
