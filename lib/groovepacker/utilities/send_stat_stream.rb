class SendStatStream

  def build_send_stream(tenant, order_id)
    stat_stream = build_stream(tenant, order_id)
    path = 'dashboard'
    send_stream(tenant, stat_stream, order_id, path)
  end

  def build_stream(tenant, order_id)
    stat_stream_obj =
      Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
    stat_stream_obj.get_order_stream(tenant, order_id)
  end

  def send_stream(tenant, stat_stream, order_id, path)
    begin
      HTTParty::Basement.default_options.update(verify: false) if !Rails.env.production?
      response = HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/#{path}",
        query: {tenant_name: tenant},
        body: stat_stream.to_json,
        headers: { 'Content-Type' => 'application/json', 'tenant' => tenant })
      if response.response.code == '200'
        order = Order.find(order_id)
        order.set_traced_in_dashboard
      end
    rescue => e
      GroovelyticsMailer.groovelytics_request_failed(tenant, e).deliver
    end
  end

  def duplicate_groovlytic_tenant(current_tenant, duplicate_name)
    HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/tenants/duplicate",
          query: {current_tenant: "#{current_tenant}stat", duplicate_name: "#{duplicate_name}stat"},
          headers: { 'Content-Type' => 'application/json', 'tenant' => current_tenant }))
  end

  def send_order_exception(order_id, tenant)
    stat_stream = build_stream(tenant, order_id)
    path = 'dashboard/update_order_data'
    send_stream(tenant, stat_stream, order_id, path)
  end

  def update_stats(tenant)
    path = "/dashboard/run_stat_stream"
    HTTParty.get("#{ENV["GROOV_ANALYTIC_URL"]}/#{path}",
          headers: { 'Content-Type' => 'application/json', 'tenant' => tenant }) 
  end

  def generate_export(tenant, params)
    days = params["duration"]
    email = params["email"]
    path = "/dashboard/generate_stats"
    HTTParty.get("#{ENV["GROOV_ANALYTIC_URL"]}/#{path}",
          query: {tenant_name: tenant, days: days, email: email},
          headers: { 'Content-Type' => 'application/json', 'tenant' => tenant })
  end
end
