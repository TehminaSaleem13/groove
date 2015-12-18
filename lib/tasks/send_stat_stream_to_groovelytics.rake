namespace :cssa do
  desc "Creates StatStream And Sends To Groovelytics Server"
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        stat_stream_obj =
          Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
        stat_stream = stat_stream_obj.stream_detail(tenant.name)
        unless stat_stream.empty?
          HTTParty.post("#{ENV["GROOV_ANALYTIC"]}/dashboard",
            query: {tenant_name: tenant.name, stat_stream: stat_stream})
        end
      rescue Exception => e
        puts e.message
        break
      end
    end
  task :send_stat_stream => :environment do
  end
end
