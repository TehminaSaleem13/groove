class AddPostCodeToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipstation_rest_credentials, :postcode, :string, default: ''
  end
end
