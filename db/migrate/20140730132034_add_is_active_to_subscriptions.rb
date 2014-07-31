class AddIsActiveToSubscriptions < ActiveRecord::Migration
  def up
    add_column :subscriptions, :is_active, :boolean
  end
  def down
  	remove_column :subscriptions, :is_active
  end
end
