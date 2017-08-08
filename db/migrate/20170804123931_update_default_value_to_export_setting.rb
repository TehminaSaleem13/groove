class UpdateDefaultValueToExportSetting < ActiveRecord::Migration
  def up
  	change_column :export_settings, :stat_export_type, :string, :default => '1'
  end

  def down
  	change_column :export_settings, :stat_export_type, :string, :default => '30'
  end
end
