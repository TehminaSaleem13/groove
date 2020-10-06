class UpdateDefaultValueToExportSetting < ActiveRecord::Migration[5.1]
  def up
  	change_column :export_settings, :stat_export_type, :string, :default => '1'
  end

  def down
  	change_column :export_settings, :stat_export_type, :string, :default => '30'
  end
end
