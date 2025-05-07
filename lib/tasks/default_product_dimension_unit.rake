# frozen_string_literal: true

namespace :dpwf do
    desc 'modify general settings and sets default product dimension unit as inches'
    task default_product_dimension_unit: :environment do
      # for all tenants
      tenants = Tenant.pluck(:name)
      unless tenants.empty?
        tenants.each do |tenant|
          Apartment::Tenant.switch!(tenant)
          if GeneralSetting.all.length == 1
            general_settings = GeneralSetting.all.first
            general_settings.product_dimension_unit = 'inches'
            general_settings.save
          end
        rescue StandardError
          next
        end
      end
    end
  end
  