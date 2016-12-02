class AddColumnToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :interval, :string
  end
end
