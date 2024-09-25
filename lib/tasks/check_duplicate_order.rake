# frozen_string_literal: true

namespace :doo do
  desc 'Check the duplicated order and order items'
  task check_duplicate_order: :environment do
    next if $redis.get('check_duplicate_order')

    $redis.set('check_duplicate_order', true)
    $redis.expire('check_duplicate_order', 180)

    Tenant.where(is_cf: true).find_each do |tenant|
      Apartment::Tenant.switch! tenant.name.to_s
      orders = Order.where('created_at >= ? and status != ? ', Time.current.beginning_of_day - 1.day, 'scanned').group(:increment_id).having('count(*) >1').count
      order_items = OrderItem.where('created_at >= ? and scanned_status != ? ', Time.current.beginning_of_day - 1.day, 'scanned').select(:order_id).group(:order_id, :product_id).having('count(*) > 1').count
      ImportMailer.duplicate_order_info(tenant.name, 'order', orders).deliver if orders.any?
      ImportMailer.duplicate_order_info(tenant.name, 'order item', order_items).deliver if order_items.any?
    end
    exit(1)
  end
end
