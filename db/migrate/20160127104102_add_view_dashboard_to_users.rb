class AddViewDashboardToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :view_dashboard, :boolean, :default => false
  end
end
