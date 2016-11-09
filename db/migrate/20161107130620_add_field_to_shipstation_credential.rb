class AddFieldToShipstationCredential < ActiveRecord::Migration
  def change
  	add_column :shipstation_rest_credentials, :auto_click_create_label, :boolean, :default => false 
  end
end
