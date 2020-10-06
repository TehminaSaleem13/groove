class AddLogToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :activity_log, :text
  end
end
