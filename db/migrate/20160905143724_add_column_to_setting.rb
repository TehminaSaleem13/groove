class AddColumnToSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :stat_status, :string
  end
end
