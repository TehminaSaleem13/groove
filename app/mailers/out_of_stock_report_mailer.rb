# frozen_string_literal: true

class OutOfStockReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def send_email(mail_settings)
    @mail_data = mail_settings

    mail to: mail_settings['email'],
         subject: "Out of stock reported #{mail_settings['location'].present? ? " at #{mail_settings['location']}" : ''} on #{mail_settings['tenant_name']} by #{mail_settings['sender']} #OUTOFSTOCK"
  end
end
