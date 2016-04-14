class DeleteOrders
  include Delayed::RecurringJob
  run_every 1.day
  run_at '12:00am'
  timezone 'US/Pacific'
  queue 'delete orders'
  priority 10

  def initialize(attrs={})
    @tenant = attrs[:tenant]
  end

  def perform
    unless @tenant.blank?
      tenant = Tenant.find_by_name(@tenant)
      perform_for_single_tenant(tenant)
    else
      tenants = Tenant.all
      tenants.each do |tenant|
        perform_for_single_tenant(tenant)
      end
    end
  end

  def perform_for_single_tenant(tenant)
    begin
      Apartment::Tenant.switch(tenant.name)
      #@orders = Order.where('updated_at < ?', (Time.now.utc - 90.days).beginning_of_day )
      @orders = Order.find(:all, :conditions => ["updated_at < ?", 90.days.ago])
      return if @orders.empty?
      take_backup(tenant.name)
      delete_orders
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
    end
   end

  def take_backup(tenant)
    file_name = "#{tenant}-#{Date.today.to_s}"
    system "mysqldump #{tenant} -uroot -proot > public/delete_orders/#{file_name}.sql"
    data = File.read("public/delete_orders/#{file_name}.sql")
    GroovS3.create_order_backup(tenant, "#{file_name}.sql", data)
    system "rm public/delete_orders/#{file_name}.sql"


    #back_hash = []
    #back_hash.push(build_store_user_hash('stores'))
    #back_hash.push(build_store_user_hash('users'))
    #@orders.each do |order|
    #  back_hash.push(build_hash(order.id))
    #end
    #puts back_hash.inspect
    #file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')
    #GroovS3.create_order_backup(tenant, file_name, back_hash.to_s)
  end

  def delete_orders
    tenant = Apartment::Tenant.current
    count = 1
    @orders.each_slice(500) do |orders|
      puts "================#{count}==================="
      orders_ids = orders.map(&:id)
      delete_order_data(orders_ids, tenant)
      Order.delete_all(["id IN (?)", orders_ids])
      count = count+1
    end
  end

  def delete_order_data(orders_ids, tenant)
    delete_items(tenant, orders_ids)
    OrderActivity.delete_all(["order_id IN (?)", orders_ids])
    OrderException.delete_all(["order_id IN (?)", orders_ids])
    OrderSerial.delete_all(["order_id IN (?)", orders_ids])
    OrderShipping.delete_all(["order_id IN (?)", orders_ids])
    # delete('order_activities', 'order_id', tenant, orders_ids)
    # delete('order_exceptions', 'order_id', tenant, orders_ids)
    # delete('order_serials', 'order_id', tenant, orders_ids)
    # delete('order_shippings', 'order_id', tenant, orders_ids)

    #delete_items(order.id)
    #order.order_activities.destroy_all unless order.order_activities.empty?
    #order.order_exception.destroy if order.order_exception
    #order.order_serials.destroy_all unless order.order_serials.empty?
    #order.order_shipping.destroy if order.order_shipping
    #order.destroy
  end

  def delete_items(tenant, orders_ids)
    order_items = OrderItem.where("order_id IN (?)", orders_ids)
    order_items_ids = order_items.map(&:id)
    OrderItemKitProduct.delete_all(["order_item_id IN (?)", order_items_ids])
    OrderItemOrderSerialProductLot.delete_all(["order_item_id IN (?)", order_items_ids])
    OrderItemScanTime.delete_all(["order_item_id IN (?)", order_items_ids])
    order_items.destroy_all

    # order = Order.find(id)
    # order_items = order.order_items
    # return if order_items.empty?
    # order_items.each do |item|
    #   item.order_item_kit_products.destroy_all unless item.order_item_kit_products.empty?
    #   item.order_item_order_serial_product_lots. destroy_all unless item.order_item_order_serial_product_lots.empty?
    #   item.order_item_scan_times.destroy_all unless item.order_item_scan_times.empty?
    #   item.destroy
    # end
  end

  def build_store_user_hash(key)
    result = {}
    result[key] = []
    if key == 'stores'
      columns = Store.column_names
      items = Store.all
    elsif key == 'users'
      columns = User.column_names
      items = User.all
    end
   
    items.each do |item|
      item_hash = {}
      columns.each do |column|
        item_hash[column] = item[column].to_s
      end
      result[key].push(item_hash)
    end   
   
    result
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
    build_product_hash(@order_items)
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

  def build_product_hash(items)
    product_columns = Product.column_names

    items.each do |item|
      @product = item.product
      if @product
        result = {}
        product_columns.each do |column|
          result[column] = @product[column].to_s
        end
        @record_hash['products'].push(result)
      end
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
      "order_item_scan_times" => [],
      "products" => []
    }
  end
end

