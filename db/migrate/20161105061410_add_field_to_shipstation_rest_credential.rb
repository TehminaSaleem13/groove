class AddFieldToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipstation_rest_credentials, :switch_back_button, :boolean, :default => false 
  end
end
