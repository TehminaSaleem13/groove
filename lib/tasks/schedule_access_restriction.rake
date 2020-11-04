namespace :doo do
  desc "Schedule AccessRestriction"
  task :schedule_access_restriction => :environment do
    Tenant.all.each do |tenant|
      tenant_name = tenant.name
      day = tenant.created_at.strftime("%d").to_i
      Delayed::Job.where(queue: "reset_access_restrictions_#{tenant_name}").destroy_all
      ApplyAccessRestrictions.new.delay(
          run_at: Time.now.change(day: "#{day}").beginning_of_day,
          queue: "reset_access_restrictions_#{tenant_name}",
          priority: 95
        ).apply_access_restrictions(tenant_name)
    end
    exit(1)
  end
end
