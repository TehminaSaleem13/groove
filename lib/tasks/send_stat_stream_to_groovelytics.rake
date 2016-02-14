namespace :cssa do
  desc "Creates StatStream And Sends To Groovelytics Server"

  task :send_stat_stream, [:arg1, :arg2] => :environment do |t, args|
    args.each do |arg|
      begin
        stat_stream_obj =
          Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
        puts "calculate stat_stream"
        stat_stream = stat_stream_obj.stream_detail(arg[1])
        unless stat_stream.empty?
          stream_count = stat_stream.size
          puts "send each stat_stream_hash"
          stat_stream.each_with_index do |stat_stream_hash, index|
            HTTParty.post("http://#{arg[1]}stat.#{ENV["GROOV_ANALYTIC"]}/dashboard",
              query: {tenant_name: arg[1], bulk_create: true, index: index, total: stream_count},
              debug_output: $stdout,
              body: stat_stream_hash.to_json,
              headers: { 'Content-Type' => 'application/json' })
            if (index % 500 == 0)
              sleep 5
            end
          end
        end
      rescue Exception => e
        puts "Exception occurred."
        puts e.message
        break
      end
    end
    exit(1)
  end
end
