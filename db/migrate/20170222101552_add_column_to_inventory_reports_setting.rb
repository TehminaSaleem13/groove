class AddColumnToInventoryReportsSetting < ActiveRecord::Migration
  def change
  	add_column :inventory_reports_settings, :report_days_option, :boolean, :default => true
  	add_column :inventory_reports_settings, :report_option, :string
  end
end
