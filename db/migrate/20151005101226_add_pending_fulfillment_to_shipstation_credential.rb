class AddPendingFulfillmentToShipstationCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :shall_import_pending_fulfillment, :boolean, default: false
  end
end
