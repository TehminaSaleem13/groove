class AddRemoveCancelledOrdersToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :remove_cancelled_orders, :boolean, default: false
  end
end
