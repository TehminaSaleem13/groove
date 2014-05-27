class AddShowWeightToAmazonCredentials < ActiveRecord::Migration
  def up
  	add_column :amazon_credentials, :show_product_weight, :boolean, :default => 1
  	add_column :amazon_credentials, :show_shipping_weight, :boolean, :default => 0
  end
  def down
  	remove_column :amazon_credentials, :show_product_weight
  	remove_column :amazon_credentials, :show_shipping_weight
  end
end
