class AddColumnToShipstationCredential < ActiveRecord::Migration
  def change
  	add_column :shipstation_rest_credentials, :use_chrome_extention, :boolean, :default => false 
  end
end
