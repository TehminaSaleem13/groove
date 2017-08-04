namespace :doo do
  desc "Check the export report and send email"
  task :scheduled_stat_export => :environment do
    Tenant.all.each do |tenant|
    	begin
	      Apartment::Tenant.switch tenant.name
		  export_setting = ExportSetting.last
		  if export_setting.auto_stat_email_export && export_setting.stat_export_email.present?
	  	    day = DateTime.now.strftime("%A")
	  	    result = false
		    if day=='Sunday' && export_setting.send_stat_export_email_on_sun
		      result = true
		    elsif day=='Monday' && export_setting.send_stat_export_email_on_mon
		      result = true
		    elsif day=='Tuesday' && export_setting.send_stat_export_email_on_tue
		      result = true
		    elsif day=='Wednesday' && export_setting.send_stat_export_email_on_wed
		      result = true
		    elsif day=='Thursday' && export_setting.send_stat_export_email_on_thu
		      result = true
		    elsif day=='Friday' && export_setting.send_stat_export_email_on_fri
		      result = true
		    elsif day=='Saturday' && export_setting.send_stat_export_email_on_sat
		      result = true
		    end
		    params = {"duration"=>export_setting.stat_export_type.to_i, "email"=>export_setting.stat_export_email}
		    time = export_setting.time_to_send_stat_export_email
		    stat_stream_obj = SendStatStream.new()
			stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'update_stats').update_stats(tenant.name)
		    stat_stream_obj = SendStatStream.new()
		    stat_stream_obj.delay(:run_at => time.strftime("%H:%M:%S"), :queue => 'generate_export').generate_export(tenant.name, params)
		  end
		rescue
		end
	end
    puts "task complete"
    exit(1)
  end
end
