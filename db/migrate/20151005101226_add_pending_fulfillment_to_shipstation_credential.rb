class AddPendingFulfillmentToShipstationCredential < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :shall_import_pending_fulfillment, :boolean, default: false
  end
end
