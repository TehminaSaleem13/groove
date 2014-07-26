class TransactionEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_email(subscription)
    attachments.inline['logo.png'] = 
      File.read("#{Rails.root}/public/images/logo.png")
    @tenant_name = subscription.tenant_name
    @email = subscription.email
  	mail to: subscription.email, 
  		subject: "GroovePacker Access Information"
  end
end