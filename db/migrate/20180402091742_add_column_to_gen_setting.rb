class AddColumnToGenSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :from_import, :datetime, :default => '2000-01-01 00:00:00'
    add_column :general_settings, :to_import, :datetime, :default => '2000-01-01 00:00:00'
  end
end
