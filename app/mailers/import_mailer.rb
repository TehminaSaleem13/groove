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
end
