class Changeapivalidationshipstaion < ActiveRecord::Migration[5.1]
  def up
    change_column :shipstation_rest_credentials, :api_key, :string, null: true
    change_column :shipstation_rest_credentials, :api_secret, :string, null: true
  end

  def down
    change_column :shipstation_rest_credentials, :api_key, :string , null: false
    change_column :shipstation_rest_credentials, :api_secret, :string, null: false
  end
end
