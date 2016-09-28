class GroovelyticsMailer < ActionMailer::Base
	default from: "app@groovepacker.com"

	def groovelytics_request_failed(tenant, error_raised_manualy, error)
      @error_raised_manualy = error_raised_manualy
      @error = error
      subject = "HTTParty post request to groovelytics server from #{tenant} failed"
      mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"], subject: subject
	end
end
