class AddSubscriptionPlanIdToSubscriptions < ActiveRecord::Migration
  def up
    add_column :subscriptions, :subscription_plan_id, :string
  end
  def down
  	remove_column :subscriptions, :subscription_plan_id
  end
end
