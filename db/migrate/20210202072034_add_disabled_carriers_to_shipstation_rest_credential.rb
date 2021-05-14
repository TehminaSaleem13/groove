class AddDisabledCarriersToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :disabled_carriers, :text
  end
end
