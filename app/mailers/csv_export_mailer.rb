class CsvExportMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def send_s3_object_url(filename, object_url, tenant)
    Apartment::Tenant.switch(tenant)
    general_setting = GeneralSetting.all.first
    recipients = [general_setting.admin_email]
    user_emails = general_setting.export_csv_email.split(',') rescue []
    user_emails.each do |email|
      recipients << email
    end
    @filename = filename
    @object_url = object_url
    subject = "Backup successful."
    mail to: recipients, subject: subject if recipients.compact.present?
  end

  def send_s3_product_object_url(filename, object_url, tenant, no_product)
    Apartment::Tenant.switch(tenant)
    general_setting = GeneralSetting.all.first
    recipients = [general_setting.email_address_for_packer_notes]
    @no_product = "Empty" if no_product
    @filename = filename
    @object_url = object_url
    subject = "Products Export Report."
    mail to: recipients, subject: subject
  end

  def unscanned_csv(filename, tenant)
    Apartment::Tenant.switch(tenant)
    attachments[filename] = File.read("public/#{filename}")
    mail to: ENV["UNSCANNED_ORDERS_EMAILS"], subject: "GroovePacker Unscanned Export Report"
  end

  def product_restore(tenant)
    Apartment::Tenant.switch(tenant)
    recipients = GeneralSetting.all.first.export_csv_email.split(',') rescue []
    mail to: recipients, subject: "GroovePacker Product Restore Is Completed"
  end

  def send_s3_broken_image_url(url, tenant)
    recipients = GeneralSetting.all.first.email_address_for_packer_notes.split(',') rescue []
    @url = url
    mail to: recipients, subject: "[#{tenant}] Product Broken Images CSV" if recipients.present? 
  end
end
