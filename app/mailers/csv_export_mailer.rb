class CsvExportMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def send_s3_object_url(filename, object_url, tenant)
    Apartment::Tenant.switch(tenant)
    general_setting = GeneralSetting.all.first
    recipients = [general_setting.admin_email]
    user_emails = general_setting.export_csv_email.split(',')
    user_emails.each do |email|
      recipients << email
    end
    @filename = filename
    @object_url = object_url
    subject = "Backup successful."
    mail to: recipients, subject: subject
  end
end
