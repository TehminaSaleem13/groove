namespace :cssa do
  desc "Creates StatStream And Sends To Groovelytics Server"

  task :send_stat_stream => :environment do
    tenants = Tenant.all
    puts "for each tenant"
    tenants.each do |tenant|
      begin
        stat_stream_obj =
          Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
        puts "calculate stat_stream"
        stat_stream = stat_stream_obj.stream_detail(tenant.name)
        unless stat_stream.empty?
          puts "send each stat_stream_hash"
          stat_stream.each do |stat_stream_hash|
            HTTParty.post("http://#{tenant.name}_stat.#{ENV["GROOV_ANALYTIC"]}/dashboard",
              query: {tenant_name: tenant.name},
              body: stat_stream_hash)
          end
        end
      rescue Exception => e
        puts "Exception occurred."
        puts e.message
        break
      end
    end
  end
end
