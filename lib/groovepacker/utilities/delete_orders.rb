class DeleteOrders
  include Delayed::RecurringJob
  run_every 1.day
  run_at '12:00am'
  timezone 'US/Pacific'
  queue 'delete orders'
  priority 10
  def perform
    tenants = Tenant.all
    tenants.each do |tenant|
      begin
        Apartment::Tenant.switch(tenant.name)
        # Delayed::Worker.logger.debug("Tenant: #{Apartment::Tenant.current}")
        updated_time = (DateTime.now.utc - 91.days).beginning_of_day
        orders = Order.where('updated_at < ?', updated_time)
        next if orders.empty?
        back_hash = []
        orders.each do |order|
          back_hash.push(build_hash(order.id))
        end
        file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')
        GroovS3.create_order_backup(tenant.name, file_name, back_hash.to_json)
        # puts "back_hash: " + back_hash.inspect
        orders.each do |order|
          delete_order_data(order)
        end
      rescue Exception => e
        puts e.message
      end
    end
  end

  def delete_order_data(order)
    delete_items(order.id)
    order.order_activities.destroy_all unless order.order_activities.empty?
    order.order_exception.destroy if order.order_exception
    order.order_serials.destroy_all unless order.order_serials.empty?
    order.order_shipping.destroy if order.order_shipping
    order.destroy
  end

  def delete_items(id)
    order = Order.find(id)
    order_items = order.order_items
    return if order_items.empty?
    order_items.each do |item|
      item.order_item_kit_products.destroy_all unless item.order_item_kit_products.empty?
      item.order_item_order_serial_product_lots. destroy_all unless item.order_item_order_serial_product_lots.empty?
      item.order_item_scan_times.destroy_all unless item.order_item_scan_times.empty?
      item.destroy
    end
  end

  def build_hash(id)
    record_hash = build_record_hash

    # build_order_hash
    # build_exception_hash
    # build_shipping_hash
    # build_activity_hash
    # build_serial_hash
    # build_order_item_hash
    # build_oikp_hash
    # build_oiospl_hash
    # build_oist_hash
    order = Order.find(id)
    order_columns = Order.column_names
    order_columns.each do |name|
      record_hash[:order][name] = order[name]
    end

    @exception = order.order_exception
    if @exception
      exception_columns = OrderException.column_names
      exception_columns.each do |name|
        record_hash[:order_exception][name] = @exception[name]
      end
    end

    @shipping = order.order_shipping
    if @shipping
      shipping_cloumns = OrderShipping.column_names
      shipping_cloumns.each do |name|
        record_hash[:order_shipping][name] = @shipping[name]
      end
    end

    @activities = order.order_activities
    unless @activities.empty?
      activity_columns = OrderActivity.column_names
      @activities.each do |activity|
        result = {}
        activity_columns.each do |name|
          result[name] = activity[name]
        end
        record_hash[:order_activities].push(result)
      end
    end

    @serials = order.order_serials
    unless @serials.empty?
      serial_columns = OrderSerial.column_names
      @serials.each do |serial|
        result = {}
        serial_columns.each do |name|
          result[name] = serial[name]
        end
        record_hash[:order_serials].push(result)
      end
    end

    @order_items = order.order_items
    unless @order_items.empty?
      item_columns = OrderItem.column_names
      @order_items.each do |item|
        result = {}
        item_columns.each do |name|
          result[name] = item[name]
        end
        record_hash[:order_items].push(result)
      end
    end

    @order_items.each do |item|
      @item_kit_products = item.order_item_kit_products
      unless @item_kit_products.empty?
        ikp_columns = OrderItemKitProduct.column_names
        @item_kit_products.each do |ikp|
          result = {}
          ikp_columns.each do |name|
            result[name] = ikp[name]
          end
          record_hash[:order_item_kit_products].push(result)
        end
      end

      @iospl = item.order_item_order_serial_product_lots
      unless @iospl.empty?
        iospl_columns = OrderItemOrderSerialProductLot.column_names
        @iospl.each do |i|
          result = {}
          iospl_columns.each do |name|
            result[name] = i[name]
          end
          record_hash[:order_item_order_serial_product_lots].push(result)
        end
      end

      @item_scan_times = item.order_item_scan_times
      unless @item_scan_times.empty?
        ist_columns = OrderItemScanTime.column_names
        @item_scan_times.each do |item|
          result = {}
          ist_columns.each do |name|
            result[name] = item[name]
          end
          record_hash[:order_item_scan_times].push(result)
        end
      end
    end
    record_hash
  end

  def build_record_hash
    {
      order: {},
      order_activities: [],
      order_exception: {},
      order_shipping: {},
      order_serials: [],
      order_items: [],
      order_item_kit_products: [],
      order_item_order_serial_product_lots: [],
      order_item_scan_times: []
    }
  end
end
