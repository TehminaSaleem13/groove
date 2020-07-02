namespace :doo do
  desc "update last imported store for tenant"
  task :update_last_imported_store => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant.name)
        last_import_store_type = ImportItem.last.try(:store).try(:store_type)
        last_import_store_type = 'FTP' if ImportItem.last.try(:message) != '' && last_import_store_type == 'CSV'
        tenant.update_attribute(:last_import_store_type, last_import_store_type)
      rescue
      end
    end
    exit(1)
  end
end
