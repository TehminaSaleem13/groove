class AddLogToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :activity_log, :text
  end
end
