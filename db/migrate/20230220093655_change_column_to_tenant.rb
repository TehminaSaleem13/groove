class ChangeColumnToTenant < ActiveRecord::Migration[5.1]
  def up
    change_column_default :tenants, :expo_logs_delay, false
    Tenant.update_all(expo_logs_delay: false)
  end

  def down
    change_column_default :tenants, :expo_logs_delay, true
  end
end
