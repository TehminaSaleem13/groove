namespace :suod do
  desc "delayed job for each tenant to send data of all untraced orders"

  task :send_untraced_order_data => :environment do
    send_untraced_obj = SendUntracedOrders.new()
    # send_untraced_obj.fetch_info_and_send
    if Delayed::Job.where(queue: "send_untraced_orders").empty?
      send_untraced_obj.delay(:run_at => 1.hours.from_now, :queue => 'send_untraced_orders').fetch_info_and_send
    end
    exit(1)
  end
end
