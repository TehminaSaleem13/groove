# frozen_string_literal: true

namespace :delete do
  desc 'Delete extra image from shipping easy'

  task duplicate_images: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      Apartment::Tenant.switch! tenant.name
      begin
        if Store.all.map(&:store_type).include?('ShippingEasy')
          Product.all.each do |pro|
            if pro.product_images.count > 1
              images = pro.product_images[1..-1]
              images.each(&:destroy)
            end
          end
        end
      rescue Exception => e
        puts e.message
      end
    end
  end
end
