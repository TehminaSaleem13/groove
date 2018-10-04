namespace :doo do
  desc "Check daily packed export report and send email"
  task :scheduled_daily_export => :environment do
    if $redis.get("scheduled_daily_export").blank?
        $redis.set("scheduled_daily_export", true) 
        $redis.expire("scheduled_daily_export", 5400) 
      Tenant.all.each do |tenant|
        begin
          Apartment::Tenant.switch tenant.name
        export_setting = ExportSetting.last
        if export_setting.daily_packed_email_export && export_setting.daily_packed_email.present?
            day = DateTime.now.strftime("%A")
            result = false
          if day=='Sunday' && export_setting.daily_packed_email_on_sun
            result = true
          elsif day=='Monday' && export_setting.daily_packed_email_on_mon
            result = true
          elsif day=='Tuesday' && export_setting.daily_packed_email_on_tue
            result = true
          elsif day=='Wednesday' && export_setting.daily_packed_email_on_wed
            result = true
          elsif day=='Thursday' && export_setting.daily_packed_email_on_thu
            result = true
          elsif day=='Friday' && export_setting.daily_packed_email_on_fri
            result = true
          elsif day=='Saturday' && export_setting.daily_packed_email_on_sat
            result = true
          end
        end
        if result
          export_setting.method("schedule_job").call("daily_packed", export_setting.time_to_send_daily_packed_export_email)
        end  
      rescue
      end
    end
  end
    puts "task complete"
    exit(1)
  end
end
