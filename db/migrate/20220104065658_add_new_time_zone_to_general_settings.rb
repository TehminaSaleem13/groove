class AddNewTimeZoneToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :new_time_zone, :string, default: 'UTC'
  end
end
