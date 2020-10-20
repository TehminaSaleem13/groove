class AddDailyPackedToggleToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :daily_packed_toggle, :boolean, default: false
  end
end
