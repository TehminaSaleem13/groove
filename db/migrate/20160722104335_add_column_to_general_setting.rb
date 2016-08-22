class AddColumnToGeneralSetting < ActiveRecord::Migration
   def change
    add_column :general_settings, :time_zone, :string
  end
end
