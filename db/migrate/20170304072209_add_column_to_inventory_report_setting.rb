class AddColumnToInventoryReportSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :inventory_reports_settings, :report_days_option, :integer, :default => 1
  end
end
