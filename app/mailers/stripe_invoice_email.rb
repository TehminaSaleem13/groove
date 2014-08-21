class StripeInvoiceEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_invoice(invoice, tenant_name)
    Apartment::Tenant.switch()
    tenant = Tenant.where(name: tenant_name).first unless Tenant.where(name: tenant_name).nil?
    Apartment::Tenant.switch(tenant_name)
    @tenant_name = tenant_name
    @invoice = invoice
  	mail to: tenant.subscription.email, 
  		subject: "GroovePacker Invoice Email"
  end
end