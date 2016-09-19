class DelayedJobMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def waiting_jobs(jobs)
    @jobs = jobs
    subject = "Groovepacker - List of the jobs waiting for worker to be assigned"
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"], subject: subject
  end

end
