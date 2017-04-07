class AddColumnToGeneralSettings < ActiveRecord::Migration
  def change
  	add_column :general_settings, :master_switch, :boolean, :default => false
  end
end
