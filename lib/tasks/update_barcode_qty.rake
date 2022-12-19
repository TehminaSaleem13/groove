# frozen_string_literal: true

namespace :doo do
  desc 'Update Barcode Qty'
  task update_barcode_qty: :environment do
    tenants = begin
                Tenant.order(:name)
              rescue StandardError
                Tenant.all
              end
    tenants.each do |tenant|
      Apartment::Tenant.switch! tenant.name
      ProductBarcode.all.each do |pro|
        pro.is_multipack_barcode = true
        pro.packing_count = 1 if pro.packing_count.blank?
        pro.save
      end
    rescue StandardError
    end
    exit(1)
  end
end
