class AddFieldToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :shopify_shop_name, :string
  end
end
