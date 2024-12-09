class AddAbbreviatedTimeZoneToGeneralSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :general_settings, :abbreviated_time_zone, :string

    GeneralSetting.all.map(&:save)
  end
end
