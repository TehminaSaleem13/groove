class StripeInvoiceEmail < ActionMailer::Base
  default from: "app@groovepacker.com"

  def send_success_invoice(invoice)
    Apartment::Tenant.switch()
    unless Subscription.where(customer_subscription_id: invoice.subscription_id, is_active: true).empty?
      subscription = Subscription.where(customer_subscription_id: invoice.subscription_id, is_active: true).first
      unless subscription.tenant.nil? || subscription.tenant.name.nil?
        tenant = subscription.tenant.name
        @email = get_customer_email_from_stripe(subscription)
        unless @email.nil?
          Apartment::Tenant.switch(tenant)
          @tenant_name = tenant
          @invoice = invoice
          mail to: [@email, 'groovepacker@gmail.com'].flatten,
               subject: "GroovePacker #{tenant} Invoice Email"
        end
      end
    end
  end

  def send_failure_invoice(invoice)
    Apartment::Tenant.switch()
    unless Subscription.where(customer_subscription_id: invoice.subscription_id, is_active: true).empty?
      subscription = Subscription.where(customer_subscription_id: invoice.subscription_id, is_active: true).first
      unless subscription.tenant.nil? || subscription.tenant.name.nil?
        tenant = subscription.tenant.name
        @email = get_customer_email_from_stripe(subscription)
        unless @email.nil?
          Apartment::Tenant.switch(tenant)
          @tenant_name = tenant
          @invoice = invoice
          mail to: [@email, 'groovepacker@gmail.com'],
               subject: "Attention Required: Account Billing Failure for "+tenant+".groovepacker.com"
        end
      end
    end
  end

  def get_customer_email_from_stripe(subscription)
    unless subscription.stripe_customer_id.nil?
      begin
        customer = Stripe::Customer.retrieve(subscription.stripe_customer_id)
        if subscription.tenant_name == "tessemaes"
          email = ["paul.sheen@tessemaes.com", "youngest@tessemaes.com"]
        else
          email = customer.email
        end
        return email
      rescue Stripe::InvalidRequestError => er
        return nil
      end
    end
  end
end
