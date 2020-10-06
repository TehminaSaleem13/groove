class AddDashboardSwitchToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :dashboard_switch, :boolean, :default => false
  end
end
