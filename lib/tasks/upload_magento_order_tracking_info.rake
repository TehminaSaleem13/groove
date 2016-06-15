namespace :doo do
  desc "Update status and tracking number for magento store for each tenant"

  task :upload_magento_order_tracking_info => :environment do
    tenants = Tenant.where(magento_tracking_push_enabled: true)
    tenants.each do |tenant|
      MagentoSoapOrders.new(tenant: tenant.name ).delay(run_at: 1.seconds.from_now, queue: "update_magento_orders_status").perform rescue nil
    end
    exit(1)
  end
end
