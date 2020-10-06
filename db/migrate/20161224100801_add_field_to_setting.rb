class AddFieldToSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :schedule_import_mode, :string
  end
end
