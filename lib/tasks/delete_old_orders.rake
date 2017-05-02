namespace :doo do
  desc "delete orders created/updated before 90 days"
  task :delete_old_orders => :environment do
    #DeleteOrders.new.schedule!
    #for single tenant run it like this -
    #DeleteOrders.new(tenant: "demo").schedule!
    #DeleteOrders.new.perform
    # t1 = Time.now
    if $redis.get("delete_old_orders").blank?
      $redis.set("delete_old_orders", true) 
      $redis.expire("delete_old_orders", 5400) 
      DeleteOrders.new.delay(run_at: 1.seconds.from_now).perform
    end
    # DeleteOrders.new.perform
    # p Time.now - t1

    exit(1)
  end
end
