# frozen_string_literal: true

namespace :cssa do
  desc 'Creates StatStream And Sends To Groovelytics Server'

  task :send_stat_stream, %i[arg1 arg2] => :environment do |_t, args|
    args.each do |arg|
      HTTParty::Basement.default_options.update(verify: false)
      stat_stream_obj =
        Groovepacker::Dashboard::Stats::AnalyticStatStream.new
      puts 'calculate stat_stream'
      stat_stream = stat_stream_obj.stream_detail(arg[1])
      unless stat_stream.empty?
        stream_count = stat_stream.size
        puts 'send each stat_stream_hash'
        stat_stream.each_with_index do |stat_stream_hash, index|
          HTTParty.post("https://#{arg[1]}stat.#{ENV['GROOV_ANALYTIC']}/dashboard",
                        query: { tenant_name: arg[1], bulk_create: true, index: index, total: stream_count },
                        debug_output: $stdout,
                        body: stat_stream_hash.to_json,
                        headers: { 'Content-Type' => 'application/json' })
          sleep 5 if index % 500 == 0
        end
      end
    rescue Exception => e
      puts 'Exception occurred.'
      puts e.message
      break
    ensure
      HTTParty::Basement.default_options.update(verify: true)
    end
    exit(1)
  end
end
