class CsvExportMailer < ActionMailer::Base
	default from: "app@groovepacker.com"

	def send_s3_object_url(filename, object_url, tenant)
		Apartment::Tenant.switch(tenant)
		@filename = filename
		@object_url = object_url
		subject = "Backup successful."
		mail to: "ksahoo@navaratan.com ", subject: subject
	end
end
