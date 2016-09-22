namespace :doo do
  desc "Update status and tracking number for magento store for each tenant"

  task :upload_magento_order_tracking_info => :environment do
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
      	Apartment::Tenant.switch(tenant.name)
      	stores = Store.includes(:magento_credentials).where("store_type='Magento' and status=true and magento_credentials.enable_status_update=true")
      	next if stores.blank?
      	MagentoSoapOrders.new(tenant: tenant.name ).delay(run_at: 1.seconds.from_now, queue: "update_magento_orders_status").perform rescue nil
      rescue
      end
    end
    exit(1)
  end
end
