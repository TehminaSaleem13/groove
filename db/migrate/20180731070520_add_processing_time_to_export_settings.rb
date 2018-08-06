class AddProcessingTimeToExportSettings < ActiveRecord::Migration
  def change
    add_column :export_settings, :processing_time, :integer, :default=>0
  end
end
