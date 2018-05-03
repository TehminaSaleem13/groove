class AddStoreKeyToShippingEasy < ActiveRecord::Migration
  def change
  	add_column :shipping_easy_credentials, :store_api_key, :string
  end
end
