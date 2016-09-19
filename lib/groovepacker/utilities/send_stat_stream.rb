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
      # response = HTTParty.post("http://#{ENV["GROOV_ANALYTIC"]}/#{path}",
      response = HTTParty.post("https://#{tenant}stat.#{ENV["GROOV_ANALYTIC"]}/#{path}",
        query: {tenant_name: tenant},
        body: stat_stream.to_json,
        headers: { 'Content-Type' => 'application/json' })
      if response.response.code == '200'
        order = Order.find(order_id)
        order.set_traced_in_dashboard
      else
        raise 'Error.'
      end
    rescue => e
      GroovelyticsMailer.groovelytics_request_failed(tenant).deliver
    end
  end

  def duplicate_groovlytic_tenant(current_tenant, duplicate_name)
    HTTParty.post("http://#{ENV["GROOV_ANALYTIC"]}/tenants/duplicate?current_tenant=#{current_tenant}stat&duplicate_name=#{duplicate_name}stat")
  end

  def send_order_exception(order_id, tenant)
    stat_stream = build_stream(tenant, order_id)
    path = 'dashboard/update_order_data'
    send_stream(tenant, stat_stream, order_id, path)
  end

  def update_stats(tenant)
    path = "/dashboard/run_stat_stream"
    HTTParty.get("https://#{tenant}stat.#{ENV["GROOV_ANALYTIC"]}/#{path}") 
  end

  def generate_export(tenant, params)
    days = params["duration"]
    email = params["email"]
    path = URI.escape("/dashboard/generate_stats?days=#{days}&email=#{email}")
    HTTParty.get("https://#{tenant}stat.#{ENV["GROOV_ANALYTIC"]}/#{path}")
  end
end
