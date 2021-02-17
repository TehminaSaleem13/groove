class AddDisabledRatesToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :disabled_rates, :text
  end
end
