class SendUsersInfo
  def build_send_users_stream(tenant, users_change_hash = nil)
    users_stream = build_stream(tenant, users_change_hash)
    send_stream(tenant, users_stream)
  end

  def build_stream(tenant, users_change_hash)
    users_stream_obj =
      Groovepacker::Dashboard::Stats::AnalyticUserInfo.new()
    users_stream_obj.users_details(tenant, users_change_hash)
  end

  def send_stream(tenant_name, users_info)
    users_info.each do |info|
      HTTParty::Basement.default_options.update(verify: false)
      HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/users/create_user",
        query: {tenant_name: tenant_name},
        body: info.to_json,
        headers: { 'Content-Type' => 'application/json', 'tenant' => tenant_name })
    end
    HTTParty::Basement.default_options.update(verify: true)
  end

  def update_gl_user(user_data, tenant_name)
    Apartment::Tenant.switch!(tenant_name)
    HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/users/update_username",
        query: { username: user_data[:username], packing_user_id: user_data[:packing_user_id] , active: user_data[:active], first_name: user_data[:first_name] , last_name: user_data[:last_name] , custom_field_one_key: user_data[:custom_field_one_key] , custom_field_one_value: user_data[:custom_field_one_value], custom_field_two_key: user_data[:custom_field_two_key], custom_field_two_value: user_data[:custom_field_two_value]},
        headers: { 'Content-Type' => 'application/json', 'tenant' => tenant_name }) rescue nil 
  end
end
