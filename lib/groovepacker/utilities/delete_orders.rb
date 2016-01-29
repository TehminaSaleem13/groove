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
        break if orders.empty?
        orders.each do |order|
          delete_items(order.id)
          order.order_activities.destroy_all unless order.order_activities.empty?
          order.order_exception.destroy_all if order.order_exception
          order.order_serials.destroy_all unless order.order_serials.empty?
          order.order_shipping.destroy_all if order.order_shipping
          order.destroy
        end
      rescue Exception => e
        puts e.message
      end
    end
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
end
