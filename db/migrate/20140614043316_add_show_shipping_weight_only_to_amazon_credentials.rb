class AddShowShippingWeightOnlyToAmazonCredentials < ActiveRecord::Migration
  def up
    add_column :amazon_credentials, :show_shipping_weight_only, :boolean, :default => 0
  end
  def down
  	remove_column :amazon_credentials, :show_shipping_weight_only
  end
end
