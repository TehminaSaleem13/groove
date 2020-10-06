class AddReportLockToInventoryReportSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :product_inventory_reports, :is_locked, :boolean, :default => false
  end
end
