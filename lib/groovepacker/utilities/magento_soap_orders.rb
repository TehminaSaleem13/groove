class MagentoSoapOrders
  include Delayed::RecurringJob
  run_every 10.minutes    # on changing 'run_every' time please change the time in 
                          # orders fetching query as well in the code below
  queue 'update_magento_orders_status'
  priority 10

  def initialize(attrs={})
    @tenant = attrs[:tenant]
  end

  def perform
    unless @tenant.blank?
      tenant = Tenant.find_by_name(@tenant)
      perform_for_tenant(tenant)
    end
  end

  def perform_for_tenant(tenant)
    begin
      Apartment::Tenant.switch(tenant.name)
      stores = Store.where(store_type: "Magento", status: true)
      return if stores.blank?
      stores.each do |store|
        credential = store.magento_credentials
        next unless credential.enable_status_update
        @orders = Order.find(:all, :conditions => ["scanned_on>? and status=? and store_id=?", 10.minutes.ago, "scanned", store.id])
        next if @orders.empty?
        handler = Groovepacker::Stores::Handlers::MagentoHandler.new(store)
        update_orders_status_at_magento(store, handler, tenant)
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
    end
  end

  def update_orders_status_at_magento(store, handler, tenant)
    handler = handler.build_handle
    credential = handler[:credential]
    client = handler[:store_handle][:handle]
    session = handler[:store_handle][:session]
    @orders.each do |order|
      response = client.call(:sales_order_add_comment, message: {
                                                                  sessionId: session, 
                                                                  orderIncrementId: order.increment_id, 
                                                                  'status' => credential.status_to_update 
                                                                }
                            )
    end
  end
end

