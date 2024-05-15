# frozen_string_literal: true

class VeeqoMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def send_sku_report_not_found(tenant, data = {}, shopify_store)
    @data = data
    @shopify_store = shopify_store
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: "[#{tenant}] Veeqo Order Imports" if recipients.present?
  end
end
