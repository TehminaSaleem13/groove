class TransactionEmail < ActionMailer::Base
  default from: "app@groovepacker.com"

  def welcome_email(subscription)
    # attachments.inline['logo.png'] =
    #     File.read("#{Rails.root}/public/images/logo.png")
    @tenant_name = subscription.tenant_name
    @user_name = subscription.user_name
    @password = subscription.password
    mail to: subscription.email,
         subject: "Welcome to Groovepacker"
  end

  def send_email(subscription)
    # attachments.inline['logo.png'] =
    #   File.read("#{Rails.root}/public/images/logo.png")
    @tenant_name = subscription.tenant_name
    @user_name = subscription.user_name
    @password = subscription.password
    mail to: subscription.email,
         subject: "GroovePacker Access Information"
  end

  def failed_subscription(subscription, exception)
    @exception = exception
    @subscription = subscription
    if @exception.nil?
      subject = "Subscription failed"
    else
      subject = "[#{subscription.tenant_name}] [#{Rails.env}] Subscription failed"
    end
    mail to: "svisamsetty@navaratan.com, groovepacker+importfail@gmail.com ", subject: subject
  end
end
