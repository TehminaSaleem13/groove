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
      HTTParty.post("https://#{tenant_name}stat.#{ENV["GROOV_ANALYTIC"]}/users/create_user",
      # HTTParty.post("http://#{ENV["GROOV_ANALYTIC"]}/users/create_user",
        query: {tenant_name: tenant_name},
        body: info.to_json,
        headers: { 'Content-Type' => 'application/json' })
    end
    HTTParty::Basement.default_options.update(verify: true)
  end
end
