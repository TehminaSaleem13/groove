namespace :doo do
  desc "Check access restriction is scheduled"
  task :schedule_check_for_access_restriction => :environment do
    if $redis.get("send_email").blank?
      $redis.set("send_email", true) 
      $redis.expire("send_email", 500)
      Tenant.all.each do |tenant|
        begin
          Apartment::Tenant.switch tenant.name
          access_restriction = AccessRestriction.order("created_at").last
          if (Date.today - Date.parse(access_restriction.created_at.strftime("%F"))).to_i > 31 && tenant.test_tenant_toggle
            StripeInvoiceEmail.remainder_for_access_restriction(tenant).deliver
          end
        rescue Exception => e
          puts e.message
          break
        end
      end 
      exit(1)
    end  
  end
end