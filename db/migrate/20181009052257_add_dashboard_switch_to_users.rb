class AddDashboardSwitchToUsers < ActiveRecord::Migration
  def change
    add_column :users, :dashboard_switch, :boolean, :default => false
  end
end
