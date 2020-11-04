namespace :fs do
  desc "delete all files created before certain time"

  task :delete_files => :environment do
    DeleteFiles.delay(:run_at => 20.seconds.from_now, priority: 95).delete_files
  end
end
