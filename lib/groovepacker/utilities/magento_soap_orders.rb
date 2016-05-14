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
    access_restrictions = AccessRestriction.last
    @orders.each do |order|
      begin
        update_order_status(client, session, order, credential)
        update_order_tracking_number(client, session, order, credential) if credential.push_tracking_number && access_restrictions.allow_magento_soap_tracking_no_push
      rescue Exception => ex
      end
    end
  end

  def update_order_status(client, session, order, credential)
    client.call(:sales_order_add_comment, message: { sessionId: session, 
                                                     orderIncrementId: order.increment_id, 
                                                     status: credential.status_to_update 
                                                  })
  end

  def update_order_tracking_number(client, session, order, credential)
    return if order.store_order_id.blank?
    shipment = client.call(:sales_order_shipment_list, message: {sessionId: session, filters: get_filters(order)})
    shipment = shipment.body[:sales_order_shipment_list_response][:result][:item]
    shipment_info = find_or_create_shipment(client, session, shipment, order)
    update_order_tracking_info_on_magento(client, session, shipment_info, order)
  end

  def get_filters(order)
    @filters ||= {"filter"=>{"item"=>{"key"=>"order_id", "value"=>order.store_order_id}}}
  end

  def find_or_create_shipment(client, session, shipment, order)
    if shipment.blank?
      shipment_info = client.call(:sales_order_shipment_create, message: {sessionId: session, orderIncrementId: order.increment_id})
      shipment_info = shipment_info.body[:sales_order_shipment_create_response]
      shipment_info[:increment_id] = shipment_info[:shipment_increment_id]
      return shipment_info
    end
    shipment_info = client.call(:sales_order_shipment_info, message: {sessionId: session, shipmentIncrementId: shipment[:increment_id]})
    shipment_info = shipment_info.body[:sales_order_shipment_info_response][:result]
  end

  def update_order_tracking_info_on_magento(client, session, shipment_info, order)
    return if order.tracking_num.blank?
    client.call(:sales_order_shipment_add_track, message: { sessionId: session,
                                                            shipmentIncrementId: shipment_info[:increment_id],
                                                            carrier: 'custom' ,
                                                            trackNumber: order.tracking_num
                                                         })
    
  end
end

