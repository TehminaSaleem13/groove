namespace :doo do
  desc "delete orders created/updated before 90 days"
  task :delete_old_orders => :environment do
    #DeleteOrders.new.schedule!
    #for single tenant run it like this -
    #DeleteOrders.new(tenant: "demo").schedule!
     DeleteOrders.new.perform
    exit(1)
  end
end
