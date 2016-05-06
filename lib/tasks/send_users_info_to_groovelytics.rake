namespace :sui do
  desc "Sends The Users Table Information To The Corresponding Database In Groovelytics"

  task :send_users_info => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      send_user_info_obj = SendUsersInfo.new()
      send_user_info_obj.build_send_users_stream(tenant.name)
    end
    exit(1)
  end  
end
