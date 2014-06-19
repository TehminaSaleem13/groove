class RemoveShowWeightFromAmazonCredentials < ActiveRecord::Migration
  def up
  	remove_column :amazon_credentials, :show_product_weight
  	remove_column :amazon_credentials, :show_shipping_weight
  end
  def down
  	add_column :amazon_credentials, :show_product_weight, :boolean, :default => 1
  	add_column :amazon_credentials, :show_shipping_weight, :boolean, :default => 0
  end
end
