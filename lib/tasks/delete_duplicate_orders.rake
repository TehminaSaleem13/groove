# frozen_string_literal: true

namespace :delete do
  desc 'delete duplicacy'

  task :duplicate_order, [:tenant] => :environment do |_t, args|
    tenants = []
    tenants = if args[:tenant].present?
                Tenant.where(name: args[:tenant])
              else
                Tenant.all
              end
    tenants.each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      Order.all.group_by(&:increment_id).each do |_key, orders|
        next if orders.count == 1

        scanned_true = ((orders.map(&:status).include? 'scanned') || (orders.map(&:status).include? 'cancelled'))
        if scanned_true
          orders.each do |dup_order|
            dup_order.destroy unless dup_order.status == 'scanned' || dup_order.status == 'cancelled'
          end
        else
          orders.drop(1).each(&:destroy)
        end
      end
    rescue StandardError
    end
  end
end
