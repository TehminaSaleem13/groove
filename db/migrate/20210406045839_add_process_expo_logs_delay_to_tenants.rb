class AddProcessExpoLogsDelayToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :expo_logs_delay, :boolean, default: true
  end
end
