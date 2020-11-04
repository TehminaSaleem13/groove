namespace :doo do
  desc "update stat for Unitedmedco"
  task :scheduled_stat_export_umi => :environment do
    stat_stream_obj = SendStatStream.new()
    stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'umi_update_stats', priority: 95).update_stats("unitedmedco")
  end
end
