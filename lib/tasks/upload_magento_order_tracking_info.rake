namespace :doo do
  desc "Update status and tracking number for magento store for each tenant"

  task :upload_magento_order_tracking_info => :environment do
    if $redis.get("upload_magento_order_tracking_info").blank?
      $redis.set("upload_magento_order_tracking_info", true) 
      $redis.expire("upload_magento_order_tracking_info", 300)
      tenants = Tenant.all 
      tenants.each do |tenant|
        begin
        	Apartment::Tenant.switch!(tenant.name)
        	stores = Store.joins(:magento_credentials).where("store_type='Magento' and status=true and magento_credentials.enable_status_update=true")
        	next if stores.blank?
        	MagentoSoapOrders.new(tenant: tenant.name ).delay(run_at: 1.seconds.from_now, queue: "update_magento_orders_status", priority: 95).perform rescue nil
        rescue
        end
      end
    end
    exit(1)
  end
end
