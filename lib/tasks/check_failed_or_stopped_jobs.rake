namespace :doo do
  desc "Check the jobs which failed or stopped in last 5 minutes"
  task :check_failed_or_stopped_jobs => :environment do
    time = Time.now-5.minutes
    not_started_jobs = Delayed::Job.where("attempts=0 and locked_at IS NULL and locked_by IS NULL and run_at<? and updated_at>=?", Time.now, time)
    DelayedJobMailer.waiting_jobs(not_started_jobs).deliver unless not_started_jobs.blank?
    puts "task complete"
    exit(1)
  end
end
