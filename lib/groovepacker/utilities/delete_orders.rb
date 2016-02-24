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
        updated_time = (DateTime.now.utc - 30.days).beginning_of_day
        @orders = Order.where('updated_at < ?', updated_time)
        next if @orders.empty?
        take_backup(tenant.name)
        delete_orders
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end
  end

  def take_backup(tenant)
    back_hash = []
    @orders.each do |order|
      back_hash.push(build_hash(order.id))
    end
    puts back_hash.inspect
    file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    GroovS3.create_order_backup(tenant, file_name, back_hash.to_s)
  end

  def delete_orders
    @orders.each do |order|
      delete_order_data(order)
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
    @record_hash = build_record_hash
    order = Order.find(id)
    build_order_hash(order)
    build_exception_hash(order)
    build_shipping_hash(order)
    build_activity_hash(order)
    build_serial_hash(order)
    
    @order_items = order.order_items
    build_order_item_hash(@order_items)

    @order_items.each do |item|
      build_oikp_hash(item)
      build_oiospl_hash(item)
      build_oist_hash(item)
    end
    @record_hash
  end

  def build_order_hash(order)
    order_columns = Order.column_names
    build_single_hash(order_columns, order, 'order')
  end

  def build_single_hash(column_names, record, hash_key)
    column_names.each do |name|
      @record_hash[hash_key][name] = record[name].to_s
    end
  end

  def build_exception_hash(order)
    @exception = order.order_exception
    if @exception
      exception_columns = OrderException.column_names
      build_single_hash(exception_columns, @exception, 'order_exception')
    end
  end

  def build_shipping_hash(order)
    @shipping = order.order_shipping
    if @shipping
      shipping_cloumns = OrderShipping.column_names
      build_single_hash(shipping_cloumns, @shipping, 'order_shipping')
    end
  end

  def build_activity_hash(order)
    @activities = order.order_activities
    return if @activities.empty?
    activity_columns = OrderActivity.column_names
    build_hash_common(@activities, activity_columns, 'order_activities')
  end

  def build_serial_hash(order)
    @serials = order.order_serials
    return if @serials.empty?
    serial_columns = OrderSerial.column_names
    build_hash_common(@serials, serial_columns, 'order_serials')
  end

  def build_order_item_hash(order_items)
    return if order_items.empty?
    item_columns = OrderItem.column_names
    build_hash_common(order_items, item_columns, 'order_items')
  end

  def build_oikp_hash(item)
    @item_kit_products = item.order_item_kit_products
    return if @item_kit_products.empty?
    ikp_columns = OrderItemKitProduct.column_names
    build_hash_common(@item_kit_products, ikp_columns, 'order_item_kit_products')
  end

  def build_oiospl_hash(item)
    @iospl = item.order_item_order_serial_product_lots
    return if @iospl.empty?
    iospl_columns = OrderItemOrderSerialProductLot.column_names
    build_hash_common(@iospl, iospl_columns, 'order_item_order_serial_product_lots')
  end

  def build_oist_hash(item)
    @item_scan_times = item.order_item_scan_times
    return if @item_scan_times.empty?
    ist_columns = OrderItemScanTime.column_names
    build_hash_common(@item_scan_times, ist_columns, 'order_item_scan_times')
  end

  def build_hash_common(items, column_names, hash_key)
    items.each do |item|
      result = {}
      column_names.each do |name|
        result[name] = item[name].to_s
      end
      @record_hash[hash_key].push(result)
    end
  end

  def build_record_hash
    {
      "order" => {},
      "order_activities" => [],
      "order_exception" => {},
      "order_shipping" => {},
      "order_serials" => [],
      "order_items" => [],
      "order_item_kit_products" => [],
      "order_item_order_serial_product_lots" => [],
      "order_item_scan_times" => []
    }
  end
end
