class StripeInvoiceEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_invoice(invoice)
    Apartment::Tenant.switch()
    subscription = Subscription.where(customer_subscription_id: invoice.subscription_id).first
    tenant = subscription.tenant.name
    Apartment::Tenant.switch(tenant)
    @tenant_name = tenant
    @invoice = invoice
  	mail to: "ksahoo@navaratan.com",#subscription.email, 
  		subject: "GroovePacker Invoice Email"
  end
end