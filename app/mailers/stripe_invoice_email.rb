class StripeInvoiceEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_success_invoice(invoice)
    Apartment::Tenant.switch()
    unless Subscription.where(customer_subscription_id: invoice.subscription_id).empty?
      subscription = Subscription.where(customer_subscription_id: invoice.subscription_id).first
      unless subscription.tenant.nil? || subscription.tenant.name.nil?
        tenant = subscription.tenant.name
        Apartment::Tenant.switch(tenant)
        @tenant_name = tenant
        @invoice = invoice
        mail to: subscription.email, 
          subject: "GroovePacker Invoice Email"
      end
    end
  end

  def send_failure_invoice(invoice)
    Apartment::Tenant.switch()
    unless Subscription.where(customer_subscription_id: invoice.subscription_id).empty?
      subscription = Subscription.where(customer_subscription_id: invoice.subscription_id).first
      unless subscription.tenant.nil? || subscription.tenant.name.nil?
        tenant = subscription.tenant.name
        Apartment::Tenant.switch(tenant)
        @tenant_name = tenant
        @invoice = invoice
        mail to: subscription.email, 
          subject: "Attention Required: Account Billing Failure for "+tenant+".groovepacker.com"
      end
    end
  end
end