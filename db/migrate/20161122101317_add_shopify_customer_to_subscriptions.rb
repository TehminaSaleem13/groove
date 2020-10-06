class AddShopifyCustomerToSubscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :subscriptions, :shopify_customer, :boolean, :default => false
    add_column :subscriptions, :all_charges_paid, :boolean, :default => false
  end
end
