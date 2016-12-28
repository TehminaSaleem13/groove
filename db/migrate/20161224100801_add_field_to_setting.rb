class AddFieldToSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :schedule_import_mode, :string
  end
end
