class AddColumnToSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :stat_status, :string
  end
end
