namespace :doo do
  desc "Check tenant details and send email"
  task :scheduled_tenant_details => :environment do
    if $redis.get("scheduled_tenant_report").blank?
      $redis.set("scheduled_tenant_report", true) 
      $redis.expire("scheduled_tenant_report", 5400) 
      AddLogCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "download_tenant_details", priority: 95).send_tenant_log
    end
    exit(1)
  end
end
