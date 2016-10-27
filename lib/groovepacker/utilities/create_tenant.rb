class CreateTenant
  def create_tenant(subscription)
    tenant_name = subscription.tenant_name
    Apartment::Tenant.create(tenant_name)
    tenant = Tenant.create(name: tenant_name, initial_plan_id: subscription.subscription_plan_id)
    subscription.tenant = tenant
    subscription.save
    Apartment::Tenant.switch(tenant_name)
    self.apply_restrictions_and_seed(subscription)
    self.delay(run_at: 1.seconds.from_now).create_groovelytics_tenant(tenant_name)
    # self.create_groovelytics_tenant(tenant_name)

    subscription.update_progress('tenant_created')
    self.send_transaction_emails(subscription)
    # TransactionEmail.delay(run_at: 2.hours.from_now).send_email(subscription)
    # TransactionEmail.welcome_email(subscription).deliver
    # subscription.update_progress("email_sent")
  end

  def apply_restrictions_and_seed(subscription)
    ApplyAccessRestrictions.new.delay(
      run_at: 10.minutes.from_now,
      queue: "apply_access_restrictions_#{subscription.tenant_name}"
    ).apply_access_restrictions(subscription.tenant_name)
    Groovepacker::SeedTenant.new.seed(true,
                                      subscription.user_name,
                                      subscription.email,
                                      subscription.password)
  end

  def send_transaction_emails(subscription)
    TransactionEmail.delay(run_at: 2.hours.from_now).send_email(subscription)
    # TransactionEmail.welcome_email(subscription).deliver
  end

  def create_groovelytics_tenant(tenant_name)
    begin
      HTTParty::Basement.default_options.update(verify: false)
      HTTParty.post(
        "#{ENV['GROOV_ANALYTIC_URL']}/tenants",
        headers: { 'Content-Type' => 'application/json', 'tenant' => tenant_name }
      )
      send_user_info_obj = SendUsersInfo.new
      send_user_info_obj.build_send_users_stream(tenant_name)
    rescue => e
      Rails.logger.error e.backtrace.join("\n")
    ensure
      HTTParty::Basement.default_options.update(verify: true)
    end
  end
end
