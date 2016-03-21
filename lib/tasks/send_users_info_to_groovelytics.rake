namespace :send_users_info_to_groovelytics do
  desc "Sends The Users Table Information To The Corresponding Database In Groovelytics"

  task :send_users_info => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      tenant_name  = tenant.name
      analytic_user_stream =
        Groovepacker::Dashboard::Stats::AnalyticUserInfo.new()
      users_info = analytic_user_stream.users_details(tenant_name)
      users_info.each do |info|
        HTTParty.post("https://#{tenant_name}stat.#{ENV["GROOV_ANALYTIC"]}/users",
          query: {tenant_name: tenant_name},
          body: info.to_json,
          headers: { 'Content-Type' => 'application/json' })
      end
    end
  end  
end
