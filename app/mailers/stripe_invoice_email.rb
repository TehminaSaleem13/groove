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
        # remove email for tessemaes
        # if subscription.tenant_name == "tessemaes"
        #   email = ["ap@tessemaes.com"]
        # else
          email = customer.email
        # end
        return email
      rescue Stripe::InvalidRequestError => er
        return nil
      end
    end
  end

  def user_delete_request_email users, user_names
    @users = users
    @user_names = user_names
    @tenant = Apartment::Tenant.current
    mail to: ['groovepacker@gmail.com', 'groovepackerservice@gmail.com'],
         subject: "GroovePacker user delete request"
  end

  def remove_user_request_email tenant, users
    @users = users
    @tenant = tenant.name
    mail to: ['support@groovepacker.com'],subject: I18n.t('user_remove_sub', env: ENV["RAILS_ENV"] , tenant: @tenant, quantity: @users)
  end

  def annual_plan tenant, users, amount
    @users = users
    @tenant = tenant.name
    @amount = amount
    mail to: ['support@groovepacker.com'],subject: I18n.t('annual_sub', env: ENV["RAILS_ENV"] , tenant: @tenant)
  end

  def remainder_for_access_restriction tenant
    @tenant = tenant.name
    mail to: ['kcpatel006@gmail.com','support@groovepacker.com'],
         subject: "Access Restriction is not created for #{@tenant} in this month"
  end

  def add_user_notification tenant, users, access_restriction
     @users = users
     @tenant = tenant.name
     @previous_users = access_restriction.num_users
     mail to: ['support@groovepacker.com'],subject: I18n.t('add_user_sub', env: ENV["RAILS_ENV"] , tenant: @tenant, quantity: ( @users - @previous_users))
  end

  def user_remove_notification tenant, access_restriction, users
    @tenant = tenant.name
    @previous_users = access_restriction.num_users
    @users = users.to_i
    mail to: ['support@groovepacker.com'],subject: I18n.t('remove_notify_sub', env: ENV["RAILS_ENV"] , tenant: @tenant, quantity: ( @previous_users - @users))
  end

  def send_tenant_details url
    @url = url 
    mail to: ['support@groovepacker.com', 'groovepacker@gmail.com', 'kcpatel006@gmail.com' ],subject: "[#{ENV["RAILS_ENV"]}] GroovePacker Tenants details"
  end
end
