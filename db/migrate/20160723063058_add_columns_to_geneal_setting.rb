class AddColumnsToGenealSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :auto_detect, :boolean, :default => true
  	add_column :general_settings, :dst, :boolean, :default => true
  end
end
