class SendStatStream

  def build_send_stream(tenant, order_id)
    stat_stream = build_stream(tenant, order_id)
    send_stream(tenant, stat_stream, order_id)
  end

  def build_stream(tenant, order_id)
    stat_stream_obj =
      Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
    stat_stream_obj.get_order_stream(tenant, order_id)
  end

  def send_stream(tenant, stat_stream, order_id)
    begin
      # response = HTTParty.post("http://#{ENV["GROOV_ANALYTIC"]}/dashboard",
      response = HTTParty.post("http://#{tenant}stat.#{ENV["GROOV_ANALYTIC"]}/dashboard",
        query: {tenant_name: tenant},
        body: stat_stream.to_json,
        headers: { 'Content-Type' => 'application/json' })
      if response.response.code == '200'
        order = Order.find(order_id)
        order.set_traced_in_dashboard
      else
        GroovelyticsMailer.groovelytics_request_failed(tenant).deliver
      end
    rescue Exception => e
      Rails.logger.error e.backtrace.join("\n")
      GroovelyticsMailer.groovelytics_request_failed(tenant).deliver
    end
  end
end
