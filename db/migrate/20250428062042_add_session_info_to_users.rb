class AddSessionInfoToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :last_login_time, :datetime
    add_column :users, :last_logout_time, :datetime
    add_column :users, :total_login_time, :integer, default: 0
  end
end
