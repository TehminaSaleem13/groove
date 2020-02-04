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
    subject = "GroovePacker #{tenant} Backup successful."
    mail to: recipients, subject: subject if recipients.compact.present?
  end

  def send_daily_packed(object_url,tenant)
    Apartment::Tenant.switch(tenant)
    @object_url = object_url
    #general_setting = GeneralSetting.all.first
    #recipients = [general_setting.email_address_for_packer_notes]
    recipients = [ ExportSetting.first.daily_packed_email]
    subject = "Daily Packed % Report for #{tenant}"
    file_name = "#{tenant}_#{Time.now.to_i}.csv"
    attachments[file_name] = Net::HTTP.get(URI.parse(object_url)) rescue nil
    mail to: recipients , subject: subject 
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

  def send_s3_export_product_url(url, tenant)
    recipients = GeneralSetting.all.first.email_address_for_packer_notes.split(',') rescue []
    @url = url
    mail to: recipients, subject: "[#{tenant}] Product Export CSV" if recipients.present? 
  end

  def send_product_barcode_label(url, tenant)
    recipients = GeneralSetting.all.first.email_address_for_packer_notes.split(',') rescue []
    @url = url
    mail to: recipients, subject: "[#{tenant}] Product Barcode Label" if recipients.present?
  end

  def import_log(url, tenant, order)
    @url = url
    mail to: ENV["PRODUCTS_IMPORT_EMAILS"], subject: "[#{tenant}] #{order} CSV Log"
  end

  def export_scanned_time_log(url)
    @url = url
    mail to: ENV["PRODUCTS_IMPORT_EMAILS"], subject: "Export log with fetching time" 
  end

  def send_csv(url)
    @url = url
    mail to: ['groovepacker@gmail.com', 'groovepackerservice@gmail.com','kcpatel006@gmail.com'], subject: "[#{ENV["RAILS_ENV"]}] Activity Log"
  end
end
