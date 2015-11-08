class ApplyAccessRestrictions

  def apply_access_restrictions(tenant_name, plan_id)
    Apartment::Tenant.switch()
    unless Subscription.where(tenant_name: tenant_name, is_active: true).empty?
      subscription = Subscription.where(tenant_name: tenant_name, is_active: true).first
      unless subscription.tenant.nil?
        Apartment::Tenant.switch(tenant_name)
        access_restriction = AccessRestriction.order("created_at").last unless AccessRestriction.order("created_at").last.nil?
        unless access_restriction.nil?
          AccessRestriction.create(num_users: access_restriction.num_users, num_shipments: access_restriction.num_shipments, num_import_sources: access_restriction.num_import_sources).save
        else
          if plan_id == "groove-solo"
            create_restriction(1, 500, 1, 0)
          elsif plan_id == 'groove-duo'
            create_restriction(2, 2000, 2, 0)
          elsif plan_id == 'groove-trio'
            create_restriction(3, 6000, 3, 0)
          elsif plan_id == 'groove-quintet'
            create_restriction(5, 12000, 5, 0)
          elsif plan_id == 'groove-symphony'
            create_restriction(12, 50000, 8, 0)
          elsif plan_id == "annual-groove-solo"
            create_restriction(1, 500, 1, 0)
          elsif plan_id == 'annual-groove-duo'
            create_restriction(2, 2000, 2, 0)
          elsif plan_id == 'annual-groove-trio'
            create_restriction(3, 6000, 3, 0)
          elsif plan_id == 'annual-groove-quintet'
            create_restriction(5, 12000, 5, 0)
          elsif plan_id == 'annual-groove-symphony'
            create_restriction(12, 50000, 8, 0)
          end
        end
      end
      ApplyAccessRestrictions.new.delay(:run_at => (Time.now + 1.month).beginning_of_day, :queue => "reset_access_restrictions_#{tenant_name}").apply_access_restrictions(tenant_name, plan_id)
    end
  end

  def create_restriction(num_users, num_shipments, num_import_sources, total_scanned_shipments)
    AccessRestriction.create(
      num_users: num_users,
      num_shipments: num_shipments,
      num_import_sources: num_import_sources,
      total_scanned_shipments: total_scanned_shipments
    )
  end
end
