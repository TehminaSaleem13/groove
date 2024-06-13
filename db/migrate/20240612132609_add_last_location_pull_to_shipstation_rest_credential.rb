class AddLastLocationPullToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :last_location_pull, :datetime
  end
end
