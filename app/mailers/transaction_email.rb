class TransactionEmail < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def send_email(subscription)
    attachments.inline['logo.png'] = 
      File.read("#{Rails.root}/public/images/logo.png")
    @user_name = subscription.user_name
    @email = subscription.email
    @password = subscription.password
  	mail to: subscription.email, 
  		subject: "GroovePacker Access Information"
  end
end