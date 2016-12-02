namespace :subscription do
  desc "Update subscription interval for each tenant"

  task :update_interval => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
      	Apartment::Tenant.switch(tenant.name)
        subscription = Subscription.where(:tenant_name => tenant.name).first 	
      	next if subscription.blank?
      	subscription.interval = Stripe::Plan.retrieve(subscription.subscription_plan_id)["interval"] rescue nil
        subscription.save
      rescue
      end
    end
  end
end
