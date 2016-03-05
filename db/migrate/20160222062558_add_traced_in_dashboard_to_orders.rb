class AddTracedInDashboardToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :traced_in_dashboard, :boolean, :default => false
  end
end
