class AddLastLocationPushToShipstationRest < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :last_location_push, :datetime
  end
end
