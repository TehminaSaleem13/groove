Delayed::Worker.max_attempts = 5
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 150.minutes
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'dj.log'))

Delayed::Backend::ActiveRecord::Job.class_eval do
  if ::ActiveRecord::VERSION::MAJOR < 4 || defined?(::ActiveRecord::MassAssignmentSecurity)
    attr_accessible :priority, :run_at, :queue, :payload_object,
                    :failed_at, :locked_at, :locked_by, :handler,
                    :last_error, :attempts
  end
end
