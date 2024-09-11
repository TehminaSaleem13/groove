# frozen_string_literal: true

class ShopifyMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def recurring_payment(tenant, payment_url)
    @payment_url = payment_url
    subject = 'Shopify Payment URL inside'
    email = Subscription.where(tenant_name: tenant.name)[0].email
    mail to: email, subject: subject
  end

  def send_sku_not_found_report_during_order_import(tenant, data = {}, shopify_store, import_store)
    @data = data
    @import_store = import_store
    @shopify_store = shopify_store
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: "[#{tenant}] #{@import_store.store_type} Order Imports" if recipients.present?
  end
end
