# frozen_string_literal: true

class ApplyAccessRestrictions
  def apply_access_restrictions(tenant_name)
    @subscription = Subscription.find_by(tenant_name: tenant_name, is_active: true)
    if @subscription&.tenant
      plan_id = @subscription.subscription_plan_id
      Apartment::Tenant.switch!(tenant_name)
      # tenant = Tenant.find_by_name(tenant_name)
      # day = tenant.created_at.strftime("%d").to_i
      apply(plan_id)
      # Delayed::Job.where(queue: 'reset_access_restrictions_#{tenant_name}').destroy_all
      # ApplyAccessRestrictions.new.delay(
      #   run_at: (Time.current.change(day: "#{day}") + 1.month).beginning_of_day,
      #   queue: "reset_access_restrictions_#{tenant_name}"
      # ).apply_access_restrictions(tenant_name)
    end
  rescue Exception => e
    Rails.logger.info e.backtrace.join("\n")
  end

  def apply(plan_id)
    @access_restriction = AccessRestriction.order('created_at').last
    if @access_restriction
      AccessRestriction.create(
        num_users: @access_restriction.num_users, num_shipments: @access_restriction.num_shipments,
        num_import_sources: @access_restriction.num_import_sources,
        allow_bc_inv_push: @access_restriction.allow_bc_inv_push,
        allow_mg_rest_inv_push: @access_restriction.allow_mg_rest_inv_push,
        allow_shopify_inv_push: @access_restriction.allow_shopify_inv_push,
        allow_teapplix_inv_push: @access_restriction.allow_teapplix_inv_push,
        allow_magento_soap_tracking_no_push: @access_restriction.allow_magento_soap_tracking_no_push
      )
    else
      init = Groovepacker::Tenants::TenantInitialization.new
      init_access = init.access_limits(plan_id)
      create_restriction(init_access)
    end
  end

  def create_restriction(init_access)
    AccessRestriction.create(
      num_users: init_access[:access_restrictions_info][:max_users],
      num_administrative_users: init_access[:access_restrictions_info][:max_administrative_users],
      regular_users: init_access[:access_restrictions_info][:regular_users],
      num_shipments: init_access[:access_restrictions_info][:max_allowed],
      num_import_sources: init_access[:access_restrictions_info][:max_import_sources],
      total_scanned_shipments: 0
    )
  end
end
