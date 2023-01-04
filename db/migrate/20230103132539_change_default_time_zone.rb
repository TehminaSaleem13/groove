class ChangeDefaultTimeZone < ActiveRecord::Migration[5.1]
  def change
    change_column :general_settings, :new_time_zone, :string, default: 'Eastern Time (US & Canada)'
  end
end
