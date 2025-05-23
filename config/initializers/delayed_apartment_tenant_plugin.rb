class DelayedApartmentTenantPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    # save current tenant before enqueuing the job
    lifecycle.before :enqueue do |job|
      job.tenant = Apartment::Tenant.current
    end

    lifecycle.around :perform do |worker, job, *args, &block|
      # Switch to the saved tenant, ocurrs before deserializing this job
      if job.tenant.present?
        Apartment::Tenant.switch(job.tenant) do
          # Add aditional context setup HERE, like security context for ex.
          block.call(worker, job, *args)
        end
      else
        block.call(worker, job, *args)
      end
    rescue Apartment::TenantNotFound => e
      Rails.logger.error "ERROR: Apartment Tenant not found: \"#{job.tenant}\" in #{Apartment::Tenant.current.inspect}"
      job.destroy
    end
  end
end

Delayed::Worker.plugins << DelayedApartmentTenantPlugin
