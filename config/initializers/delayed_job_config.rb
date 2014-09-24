Delayed::Worker.max_attempts = 5
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 2.hours
