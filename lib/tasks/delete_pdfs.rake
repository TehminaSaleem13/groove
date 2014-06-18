namespace :fs do
  desc "delete all files created before certain time"

  task :delete_pdfs => :environment do
    DeleteFiles.delay(:run_at => 20.seconds.from_now).delete_pdfs
  end
end