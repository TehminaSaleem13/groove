# frozen_string_literal: true

namespace :doo do
  desc 'update last imported store for tenant'
  task update_last_imported_store: :environment do
    next if $redis.get('update_last_imported_store')

    $redis.set('update_last_imported_store', true)
    $redis.expire('update_last_imported_store', 180)
    tenants = Tenant.where(is_cf: true)
    tenants.find_each do |tenant|
      Apartment::Tenant.switch(tenant.name)
      last_import_store_type = ImportItem.last.try(:store).try(:store_type)
      last_import_store_type = 'FTP' if ImportItem.last.try(:message) != '' && last_import_store_type == 'CSV'
      tenant.update_attribute(:last_import_store_type, last_import_store_type)
    rescue StandardError
    end
    exit(1)
  end
end
