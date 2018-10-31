class ChangeDataTypeOfViewDashboard < ActiveRecord::Migration
  def up
    change_column :users, :view_dashboard, :string, :default => "none"
  end

  def down
    change_column :users, :view_dashboard, :boolean, :default => false
  end
end
