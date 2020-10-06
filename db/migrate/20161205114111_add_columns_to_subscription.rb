class AddColumnsToSubscription < ActiveRecord::Migration[5.1]
  def change
  	add_column :subscriptions, :app_charge_id, :string
  	add_column :subscriptions, :tenant_charge_id, :string
  end
end
