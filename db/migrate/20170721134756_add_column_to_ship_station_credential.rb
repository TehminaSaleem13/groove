class AddColumnToShipStationCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipstation_rest_credentials, :return_to_order, :boolean, :default => false 
  end
end
