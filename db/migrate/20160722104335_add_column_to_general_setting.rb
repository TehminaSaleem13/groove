class AddColumnToGeneralSetting < ActiveRecord::Migration[5.1]
   def change
    add_column :general_settings, :time_zone, :string
  end
end
