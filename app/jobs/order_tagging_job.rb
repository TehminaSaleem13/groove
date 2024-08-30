# app/jobs/order_tagging_job.rb

class OrderTaggingJob < ActiveJob::Base
  queue_as :default

  def perform(tag_ids, order_ids, operation, total_batches)
    orders = Order.where(id: order_ids)
    tags = OrderTag.where(id: tag_ids)

    case operation
    when 'add'
      tags.each do |tag|
        orders.each { |order| order.order_tags << tag }
      end
    when 'remove'
      tags.each do |tag|
        orders.each { |order| order.order_tags.destroy(tag) }
      end
    end

    # Increment the completion count in Redis
    $redis.incr("order_tagging_job:completed_batches")

    # Check if all batches are completed
    completed_batches = $redis.get("order_tagging_job:completed_batches").to_i
    if completed_batches == total_batches
      GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)
      
      # Clean up Redis keys
      $redis.del("order_tagging_job:total_batches")
      $redis.del("order_tagging_job:completed_batches")
    end
  end
end
