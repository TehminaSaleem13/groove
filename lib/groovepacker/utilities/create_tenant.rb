class CreateTenant
  def create_tenant(subscription)
    Apartment::Tenant.create(subscription.tenant_name)
    tenant = Tenant.create(name: subscription.tenant_name)
    subscription.tenant = tenant
    HTTParty.post("#{ENV["GROOV_ANALYTIC"]}/tenants",
      query: {tenant_name: subscription.tenant_name})
    Apartment::Tenant.switch(subscription.tenant_name)
    ApplyAccessRestrictions.new.delay(:run_at => 10.minutes.from_now, :queue => "apply_access_restrictions_#{subscription.tenant_name}").apply_access_restrictions(subscription.tenant_name, subscription.subscription_plan_id)
    Groovepacker::SeedTenant.new.seed(true,
                                      subscription.user_name,
                                      subscription.email,
                                      subscription.password
    )
    subscription.update_progress("tenant_created")
    TransactionEmail.delay(run_at: 2.hours.from_now).send_email(subscription)
    TransactionEmail.welcome_email(subscription).deliver
    subscription.update_progress("email_sent")
  end
end
