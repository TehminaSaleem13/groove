# frozen_string_literal: true

namespace :doo do
  desc 'Schedule AccessRestriction'
  task schedule_access_restriction: :environment do
    if $redis.get('job_schedule_access_restriction').blank?
      $redis.set('job_schedule_access_restriction', true)
      $redis.expire('job_schedule_access_restriction', 500)

      Tenant.find_each do |tenant|
        tenant_name = tenant.name
        day = tenant.created_at.strftime('%d').to_i
        Delayed::Job.where(queue: "reset_access_restrictions_#{tenant_name}").destroy_all
        ApplyAccessRestrictions.new.delay(
          run_at: Time.current.change(day: day.to_s).beginning_of_day,
          queue: "reset_access_restrictions_#{tenant_name}",
          priority: 95
        ).apply_access_restrictions(tenant_name)
      end
    end
    exit(1)
  end
end
