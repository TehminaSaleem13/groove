class AddNewFieldToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :full_name, :string, default: ''
    add_column :shipstation_rest_credentials, :street1, :string, default: ''
    add_column :shipstation_rest_credentials, :street2, :string, default: ''
    add_column :shipstation_rest_credentials, :city, :string, default: ''
    add_column :shipstation_rest_credentials, :state, :string, default: ''
    add_column :shipstation_rest_credentials, :country, :string, default: ''
  end
end
