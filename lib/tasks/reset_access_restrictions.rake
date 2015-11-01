namespace :schedule do
  desc "delayed job for each tenant to reset access restrictions"

  task :reset_access_restrictions => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        unless Subscription.where(tenant_name: tenant.name, is_active: true).empty?
          subscription = Subscription.where(tenant_name: tenant.name, is_active: true).first
          unless subscription.tenant.nil?
            Apartment::Tenant.switch(tenant_name)
            access_restriction = AccessRestriction.order("created_at").last unless AccessRestriction.order("created_at").empty?
            unless access_restriction.nil?
              if access_restriction.created_at < Time.now - 1.month
                ApplyAccessRestrictions.new.delay(:run_at => (access_restriction.created_at + 1.month).beginning_of_day, :queue => "reset_access_restrictions_#{tenant_name}").apply_access_restrictions(tenant.name, tenant.plan_id)
              else
                while access_restriction.created_at < 1.month
                  access_restriction.created_at += 1.month
                end
                ApplyAccessRestrictions.new.delay(:run_at => (access_restriction.created_at).beginning_of_day, :queue => "reset_access_restrictions_#{tenant_name}").apply_access_restrictions(tenant.name, tenant.plan_id)
              end
            else
              ApplyAccessRestrictions.new.delay(:run_at => 10.minutes.from_now, :queue => "apply_access_restrictions_#{subscription.tenant_name}").apply_access_restrictions(subscription.tenant_name, subscription.subscription_plan_id)
            end
          end
        end
      rescue Exception => e
        puts e.message
      end
    end
  end
end