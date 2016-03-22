namespace :sui do
  desc "Sends The Users Table Information To The Corresponding Database In Groovelytics"

  task :send_users_info => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      tenant_name  = tenant.name
      analytic_user_stream =
        Groovepacker::Dashboard::Stats::AnalyticUserInfo.new()
      users_info = analytic_user_stream.users_details(tenant_name)
      users_info.each do |info|
        HTTParty::Basement.default_options.update(verify: false)
        HTTParty.post("https://#{tenant_name}stat.#{ENV["GROOV_ANALYTIC"]}/users/create_user",
        # HTTParty.post("http://#{ENV["GROOV_ANALYTIC"]}/users/create_user",
          query: {tenant_name: tenant_name},
          body: info.to_json,
          headers: { 'Content-Type' => 'application/json' })
      end
    end
    exit(1)
  end  
end
