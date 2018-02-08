class AddToggleToSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :html_print, :boolean, :default => false
  end
end
