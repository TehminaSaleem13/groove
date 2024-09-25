# frozen_string_literal: true

namespace :doo do
  desc 'Check the jobs which failed or stopped in last 5 minutes'
  task check_failed_or_stopped_jobs: :environment do
    if $redis.get('email_send').blank?
      $redis.set('email_send', true)
      $redis.expire('email_send', 500)
      time = Time.current - 5.minutes
      not_started_jobs = Delayed::Job.where('attempts=0 and locked_at IS NULL and locked_by IS NULL and run_at<? and updated_at>=?', time + 4.minutes + 40.seconds, time)
      DelayedJobMailer.waiting_jobs(not_started_jobs).deliver unless not_started_jobs.empty?
      puts 'task complete'
      exit(1)
    end
  end
end
