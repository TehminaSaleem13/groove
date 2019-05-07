namespace :doo do
  desc "Check tenant details and send email"
  task :scheduled_tenant_details => :environment do
    if $redis.get("scheduled_tenant_report").blank?
      $redis.set("scheduled_tenant_report", true) 
      $redis.expire("scheduled_tenant_report", 5400) 

      headers = [ "Tenant Name", "Number of Users", "Number of Products", "Plan Price", "Last Stripe Charge", "Admintools URL", "Stripe URL", "Start Date", "Billing date" ]
      data = CSV.generate do |csv|
        csv << headers if csv.count.eql? 0
        Subscription.all.each do |sub|
          t = Tenant.where(name: "#{sub.tenant_name}")
          if t.present?
            Apartment::Tenant.switch "#{sub.tenant_name}"
            tenant_id = Tenant.find_by_name("#{sub.tenant_name}").id rescue nil
            access_restriction = AccessRestriction.order("created_at").last
            customer = Stripe::Customer.retrieve("#{sub.stripe_customer_id}") rescue nil
            subscription = customer.subscriptions.retrieve("#{sub.customer_subscription_id}")  rescue nil
            total_product = subscription.items.count rescue nil
            if customer.present?
              last_stripe_amount = customer.charges.first.amount
              last_stripe_amount = ( last_stripe_amount / 100) rescue 0
              date = customer.charges.first.created
              billing_date = DateTime.strptime("#{date}",'%s')
            end
            sub_amount = (sub.amount.to_f / 100) rescue 0   
            csv << ["#{sub.tenant_name}","#{access_restriction.num_users}","#{ total_product }", "#{sub_amount}","#{last_stripe_amount}", "https://admintools.groovepacker.com/#/admin_tools/tenant/1/#{tenant_id}","https://dashboard.stripe.com/customers/#{sub.try(:stripe_customer_id)}", "#{sub.created_at}", "#{billing_date}"]
          end
        end
      end 

      url = GroovS3.create_public_csv("admintools", 'subscription',Time.now.to_i, data).url
      StripeInvoiceEmail.send_tenant_details(url).deliver
    end
  end
end
