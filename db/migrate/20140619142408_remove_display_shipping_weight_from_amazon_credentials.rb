class RemoveDisplayShippingWeightFromAmazonCredentials < ActiveRecord::Migration
  def change
  	remove_column :amazon_credentials, :display_shipping_weight
  end
end
