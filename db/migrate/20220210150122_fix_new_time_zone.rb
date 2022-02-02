# frozen_string_literal: true

class FixNewTimeZone < ActiveRecord::Migration[5.1]
  def change
    return unless GeneralSetting.last

    time_zones = Groovepacks::Application.config.time_zone_names
    offset = GeneralSetting.last.time_zone.to_i
    tz_name = Time.find_zone(time_zones.key(offset))&.name || Time.find_zone(offset)&.name || 'UTC'
    GeneralSetting.update(new_time_zone: tz_name)
  end
end
