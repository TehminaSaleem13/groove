# frozen_string_literal: true

namespace :role do
  desc 'Update User Roles Settings'
  task update_user_roles_settings: :environment do
    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        Apartment::Tenant.switch! tenant
        User.all.each do |user|
          next unless user.role.name != 'Scan & Pack User'

          user.role.update(edit_shipping_settings: true,
                                      edit_visible_services: true,
                                      add_edit_shortcuts: true,
                                      add_edit_dimension_presets: true)
        end
      end
    end
  end
end
