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
    mail to: "svisamsetty@navaratan.com, kcpatel006@gmail.com, service.groovepacker@gmail.com", subject: subject
  end
end
