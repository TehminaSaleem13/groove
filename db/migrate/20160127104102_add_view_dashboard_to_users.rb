class AddViewDashboardToUsers < ActiveRecord::Migration
  def change
    add_column :users, :view_dashboard, :boolean, :default => false
  end
end
