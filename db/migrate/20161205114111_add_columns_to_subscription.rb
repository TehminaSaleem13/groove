class AddColumnsToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :app_charge_id, :string
  	add_column :subscriptions, :tenant_charge_id, :string
  end
end
