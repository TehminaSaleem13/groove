namespace :doo do
  desc "Check the duplicated order and order items"
  task :check_duplicate_order => :environment do
    Tenant.where(is_cf: true).each do |tenant|
      Apartment::Tenant.switch! "#{tenant.name}"
      orders = Order.where("created_at >= ? and status != ? ", Time.now.beginning_of_day - 1.day, "scanned").group(:increment_id).having("count(*) >1").count
      order_items = OrderItem.where("created_at >= ? and scanned_status != ? ", Time.now.beginning_of_day - 1.day, "scanned").select(:order_id).group(:order_id, :product_id).having("count(*) > 1").count
      if orders.any? 
        ImportMailer.duplicate_order_info(tenant.name, 'order', orders).deliver
      end
      if order_items.any?
        ImportMailer.duplicate_order_info(tenant.name, 'order item', order_items).deliver
      end
    end  
    exit(1)
  end
end