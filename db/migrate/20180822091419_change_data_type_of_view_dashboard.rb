class ChangeDataTypeOfViewDashboard < ActiveRecord::Migration[5.1]
  def up
    change_column :users, :view_dashboard, :string, :default => "none"
  end

  def down
    change_column :users, :view_dashboard, :boolean, :default => false
  end
end
