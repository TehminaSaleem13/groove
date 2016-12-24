class AddHashFieldToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :tenant_data, :text
  end
end
