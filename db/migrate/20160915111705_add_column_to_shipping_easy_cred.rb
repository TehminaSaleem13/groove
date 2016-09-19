class AddColumnToShippingEasyCred < ActiveRecord::Migration
  def change
  	add_column :shipping_easy_credentials, :includes_product, :boolean, :default => false 
  end
end
