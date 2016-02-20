class ImportMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def failed(import_exception)
    @import_exception = import_exception
    if @import_exception.nil?
      subject = "Import failed"
    else
      subject = "[#{@import_exception[:tenant]}] [#{Rails.env}] Import failed"
    end
    mail to: "svisamsetty@navaratan.com, groovepacker+importfail@gmail.com ", subject: subject
  end

  def send_products_import_email(products_count, credential)
    @products_count = products_count
    @credential = credential
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] initiated products import for #{@products_count} products"
    mail to: "svisamsetty@navaratan.com, kcpatel006@gmail.com, groovepacker@gmail.com", subject: subject
  end

  def send_products_import_complete_email(products_count, result, credential)
    system_notifications_email = (GeneralSetting.first.email_address_for_packer_notes || '') rescue ''
    @products_count = products_count
    @credential = credential
    @result = result
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] products import for Store: #{@credential.store.name} is complete"
    mail to: "#{system_notifications_email}", bcc: "kcpatel006@gmail.com", subject: subject
  end
end
