class AddStripeCustomerIdToSubscriptions < ActiveRecord::Migration
  def up
    add_column :subscriptions, :stripe_customer_id, :string
  end
  def down
  	remove_column :subscriptions, :stripe_customer_id
  end
end
