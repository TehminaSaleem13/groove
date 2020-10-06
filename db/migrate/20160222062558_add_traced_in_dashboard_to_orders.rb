class AddTracedInDashboardToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :traced_in_dashboard, :boolean, :default => false
  end
end
