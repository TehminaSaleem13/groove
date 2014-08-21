class StripeInvoiceEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_invoice(invoice, tenant_name)
    Apartment::Tenant.switch(tenant)
    tenant = Tenat.where(name: tenant_name).first unless Tenat.where(name: tenant_name).nil?

  	mail to: tenant.subscription.email, 
  		subject: "GroovePacker Invoice Email"
  end
end