class AddCustomerSubscriptionIdToSubscriptions < ActiveRecord::Migration[5.1]
  def up
    add_column :subscriptions, :customer_subscription_id, :string
  end
  def down
  	remove_column :subscriptions, :customer_subscription_id
  end
end
