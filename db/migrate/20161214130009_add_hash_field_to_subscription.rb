class AddHashFieldToSubscription < ActiveRecord::Migration[5.1]
  def change
  	add_column :subscriptions, :tenant_data, :text
  end
end
