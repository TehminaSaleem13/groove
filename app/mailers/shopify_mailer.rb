class ShopifyMailer < ActionMailer::Base
    default from: "app@groovepacker.com"

    def recurring_payment(tenant, payment_url)
      @payment_url = payment_url
      subject = "Shopify Payment URL inside"
      email = Subscription.where(tenant_name: tenant.name)[0].email
      mail to: email, subject: subject
    end
end
