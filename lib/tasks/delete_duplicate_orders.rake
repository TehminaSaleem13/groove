namespace :delete do
  desc "delete duplicacy"

  task :duplicate_order, [:tenant] => :environment do |t, args|
    tenants = []
    if args[:tenant].present?
      tenants = Tenant.where(name: args[:tenant])
    else
      tenants = Tenant.all
    end
    tenants.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant.name)
        Order.all.group_by(&:increment_id).each do |key, orders|
          next if orders.count == 1
          scanned_true = ((orders.map(&:status).include? ("scanned")) || (orders.map(&:status).include? ("cancelled")))
          if scanned_true
            orders.each do |dup_order|
              dup_order.destroy if !(dup_order.status == "scanned" || dup_order.status == "cancelled")
            end
          else
            orders.drop(1).each do |dup_order|
              dup_order.destroy
            end
          end
        end
      rescue
      end
    end
  end
end
