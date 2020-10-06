class AddColumnsToGenealSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :auto_detect, :boolean, :default => true
  	add_column :general_settings, :dst, :boolean, :default => true
  end
end
