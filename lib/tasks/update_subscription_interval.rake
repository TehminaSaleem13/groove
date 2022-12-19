# frozen_string_literal: true

namespace :subscription do
  desc 'Update subscription interval for each tenant'

  task update_interval: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      subscription = Subscription.where(tenant_name: tenant.name).first
      next if subscription.blank?

      subscription.interval = begin
                              Stripe::Plan.retrieve(subscription.subscription_plan_id)['interval']
                              rescue StandardError
                                nil
                            end
      subscription.save
    rescue StandardError
    end
  end
end
