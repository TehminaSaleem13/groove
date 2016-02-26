class GroovelyticsMailer < ActionMailer::Base
	default from: "app@groovepacker.com"

	def groovelytics_request_failed(tenant)
		subject = "HTTParty post request to groovelytics server from #{tenant} failed"
		mail to: "ksahoo@navaratan.com ", subject: subject
	end
end
