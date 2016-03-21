namespace :cta do
  desc "Creates Tenants In Groovelytics Server With Same Names As In AppServer"

  task :create_tenants => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        HTTParty::Basement.default_options.update(verify: false)
        HTTParty.post("https://#{ENV["GROOV_ANALYTIC"]}/tenants",
          query: {tenant_name: tenant.name})
      rescue Exception => e
        puts e.message
        break
      ensure
        HTTParty::Basement.default_options.update(verify: true)
      end
    end
  end
end
