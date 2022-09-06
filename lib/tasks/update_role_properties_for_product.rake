namespace :system do
  desc "Update in User Role edit_product_location and edit_product_quantity"
  task :update_role_properties_for_product => :environment do

    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        begin
          Apartment::Tenant.switch! tenant
          admin_roles = Role.where(name: ['Super Admin', 'Admin', 'Manager', 'Super Super Admin'])
          admin_roles.update_all(edit_product_location: true, edit_product_quantity: true)
        end
      end
    end
  end
end
