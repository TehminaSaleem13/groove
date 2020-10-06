class AddStartTimeEndTimeToExportSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :export_settings, :start_time, :datetime
  	add_column :export_settings, :end_time, :datetime
  	add_column :export_settings, :manual_export, :boolean, :default => false
  end
end
