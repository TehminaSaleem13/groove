class AddColumnToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :master_switch, :boolean, :default => false
  end
end
