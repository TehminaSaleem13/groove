class SendStatStream

  def send(tenant, order_id)
    stat_stream = build_stream(order_id)
    send_stream(tenant, stat_stream)
  end

  def build_stream(order_id)
    stat_stream_obj =
      Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
    stat_stream_obj.build_stream(order_id)
  end

  def send_stream(tenant, stat_stream)
    begin 
      HTTParty.post("http://#{tenant}stat.#{ENV["GROOV_ANALYTIC"]}/dashboard",
        query: {tenant_name: tenant},
        body: stat_stream.to_json,
        headers: { 'Content-Type' => 'application/json' })
    rescue Exception => e
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
