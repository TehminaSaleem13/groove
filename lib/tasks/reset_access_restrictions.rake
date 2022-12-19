# frozen_string_literal: true

namespace :schedule do
  desc 'delayed job for each tenant to reset access restrictions'

  task reset_access_restrictions: :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      @subscription = Subscription.where(tenant_name: tenant.name, is_active: true).first
      if @subscription && !@subscription.tenant.nil?
        tenant_name = tenant.name
        plan_id = @subscription.subscription_plan_id
        Apartment::Tenant.switch!(tenant_name)
        @access_restriction = AccessRestriction.order('created_at').last
        if @access_restriction
          Delayed::Job.where(queue: 'reset_access_restrictions_#{tenant_name}').destroy_all
          last_created = @access_restriction.created_at
          if last_created > Time.current - 1.month
            ApplyAccessRestrictions.new.delay(run_at: (last_created + 1.month).beginning_of_day, queue: "reset_access_restrictions_#{tenant_name}", priority: 95).apply_access_restrictions(tenant_name)
          else
            last_created += 1.month while last_created < Time.current - 1.month
            ApplyAccessRestrictions.new.delay(run_at: (last_created + 1.month).beginning_of_day, queue: "reset_access_restrictions_#{tenant_name}", priority: 95).apply_access_restrictions(tenant_name)
          end
        else
          Delayed::Job.where(queue: 'apply_access_restrictions_#{tenant_name}').destroy_all
          ApplyAccessRestrictions.new.delay(run_at: 10.minutes.from_now, queue: "apply_access_restrictions_#{tenant_name}", priority: 95).apply_access_restrictions(tenant_name)
        end
      end
    rescue Exception => e
      puts e.message
    end
    exit(1)
  end
end
