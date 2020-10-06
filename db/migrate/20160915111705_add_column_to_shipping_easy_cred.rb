class AddColumnToShippingEasyCred < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipping_easy_credentials, :includes_product, :boolean, :default => false 
  end
end
