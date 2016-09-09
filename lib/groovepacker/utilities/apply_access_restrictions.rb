class ApplyAccessRestrictions
  def apply_access_restrictions(tenant_name)
    begin
      @subscription = Subscription.where(tenant_name: tenant_name, is_active: true).first
      if @subscription && @subscription.tenant
        plan_id = @subscription.subscription_plan_id
        Apartment::Tenant.switch(tenant_name)
        apply(plan_id)
        Delayed::Job.where(queue: 'reset_access_restrictions_#{tenant_name}').destroy_all
        ApplyAccessRestrictions.new.delay(
          run_at: (Time.now + 1.month).beginning_of_day,
          queue: "reset_access_restrictions_#{tenant_name}"
        ).apply_access_restrictions(tenant_name)
      end
    rescue Exception => e
      Rails.logger.info e.backtrace.join("\n")
    end
  end

  def apply(plan_id)
    access_restrictions = AccessRestriction.order('created_at')
    @access_restriction = access_restrictions.last if access_restrictions.last
    if @access_restriction
      AccessRestriction.create(num_users: @access_restriction.num_users, num_shipments: @access_restriction.num_shipments, num_import_sources: @access_restriction.num_import_sources).save
    else
      init = Groovepacker::Tenants::TenantInitialization.new
      init_access = init.access_limits(plan_id)
      create_restriction(init_access)
    end
  end

  def create_restriction(init_access)
    AccessRestriction.create(
      num_users: init_access[:access_restrictions_info][:max_users],
      num_shipments: init_access[:access_restrictions_info][:max_allowed],
      num_import_sources: init_access[:access_restrictions_info][:max_import_sources],
      total_scanned_shipments: 0
    )
  end
end
