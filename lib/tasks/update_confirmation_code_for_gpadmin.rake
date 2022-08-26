namespace :system do
  desc "Change confirmation_code for gpadmin"
  task :update_confirmation_code_for_gpadmin => :environment do

    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        begin
          Apartment::Tenant.switch! tenant
          User.find_by_username('gpadmin')&.update_attribute(:confirmation_code, 123123)
        end
      end
    end    
  end
end
