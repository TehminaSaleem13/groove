# frozen_string_literal: true

namespace :delayed_job do
  desc 'restart delayed jobs with no jobs and memory more than 500MB'

  task restart_workers: :environment do
    next if $redis.get('restart_delayed_jobs')

    $redis.set('restart_delayed_jobs', true)
    $redis.expire('restart_delayed_jobs', 180)
    worker_process = `ps aux  | awk '{print $6/1024 " MB " $11}'  | sort -n | grep delayed`.split(/\n/)

    next if worker_process.empty?

    worker_process.each do |process|
      /(?<memory>\d+).*(?<worker_name>delayed\_job\.\d+)/ =~ process
      next unless memory && worker_name && memory.to_i > 500

      jobs = Delayed::Job.where(
        "locked_by like '%#{worker_name}%' and last_error IS NULL and attempts < 5"
      )

      next unless jobs.empty?

      p "Restarting #{worker_name} with memory usage #{memory}"

      `sudo monit restart #{worker_name.tr('.', '_')}`
    end
  rescue StandardError => e
    puts e.message
    exit
  end
end
