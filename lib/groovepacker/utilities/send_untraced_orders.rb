class SendUntracedOrders
  def fetch_info_and_send
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        tenant_name = tenant.name
        Apartment::Tenant.switch(tenant_name)
        stat_stream_obj =
          Groovepacker::Dashboard::Stats::AnalyticStatStream.new()
        stat_stream = stat_stream_obj.stream_detail(tenant_name, true)
        unless stat_stream.empty?
          stat_stream_obj = SendStatStream.new()
          stat_stream.each_with_index do |stat_stream_hash, index|
            order_id = Order.where(increment_id: stat_stream_hash[:order_increment_id]).first.id
            stat_stream_obj.send_stream(tenant_name, stat_stream_hash, order_id)
            if (index % 500 == 0)
              sleep 5
            end
          end
        end
      rescue Exception => e
        puts e.message
      end
    end
    self.delay(:run_at => 1.hours.from_now, :queue => 'send_untraced_ordes').fetch_info_and_send
  end
end
