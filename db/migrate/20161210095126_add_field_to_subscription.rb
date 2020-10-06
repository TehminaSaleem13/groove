class AddFieldToSubscription < ActiveRecord::Migration[5.1]
  def change
  	add_column :subscriptions, :shopify_shop_name, :string
  end
end
