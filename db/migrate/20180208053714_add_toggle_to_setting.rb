class AddToggleToSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :html_print, :boolean, :default => false
  end
end
