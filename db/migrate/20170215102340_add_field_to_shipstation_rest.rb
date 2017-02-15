class AddFieldToShipstationRest < ActiveRecord::Migration
  def change
  	add_column :shipstation_rest_credentials, :download_ss_image, :boolean, :default => false
  end
end
