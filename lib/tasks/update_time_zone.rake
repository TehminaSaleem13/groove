# frozen_string_literal: true

namespace :general_settings do
  desc 'Update Time Zone of Tenant'
  task update_default_time_zone: :environment do
    Tenant.all.each do |tenant|
      Apartment::Tenant.switch! tenant.name
      setting = GeneralSetting.first
      next unless setting
      setting.update_columns(new_time_zone: 'Eastern Time (US & Canada)') if setting&.new_time_zone == 'UTC'
    end
  end
end