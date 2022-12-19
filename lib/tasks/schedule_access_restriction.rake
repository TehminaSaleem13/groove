# frozen_string_literal: true

namespace :doo do
  desc 'Schedule AccessRestriction'
  task schedule_access_restriction: :environment do
    Tenant.where(is_cf: true).each do |tenant|
      tenant_name = tenant.name
      day = tenant.created_at.strftime('%d').to_i
      Delayed::Job.where(queue: "reset_access_restrictions_#{tenant_name}").destroy_all
      ApplyAccessRestrictions.new.delay(
        run_at: Time.current.change(day: day.to_s).beginning_of_day,
        queue: "reset_access_restrictions_#{tenant_name}",
        priority: 95
      ).apply_access_restrictions(tenant_name)
    end
    exit(1)
  end
end
