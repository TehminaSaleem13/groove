class AddWarehouseLocationUpdateToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, 
      :warehouse_location_update, :boolean, default: false
  end
end
