namespace :role do
  desc "Update User Roles Settings"
  task :update_user_roles_settings => :environment do

    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        begin
          Apartment::Tenant.switch! tenant
          User.all.each do |user|
            if user.role.name != 'Scan & Pack User'
              user.role.update_attributes(edit_shipping_settings: true,
                                      edit_visible_services: true,
                                      add_edit_shortcuts: true,
                                      add_edit_dimension_presets: true)
            end
          end
        end
      end
    end
  end
end
  