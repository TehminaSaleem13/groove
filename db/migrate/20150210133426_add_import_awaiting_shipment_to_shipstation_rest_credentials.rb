class AddImportAwaitingShipmentToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :shall_import_awaiting_shipment, :boolean, default: true
    add_column :shipstation_rest_credentials, :shall_import_shipped, :boolean, default: false
  end
end
