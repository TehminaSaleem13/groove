# app/jobs/order_tagging_job.rb

class OrderTaggingJob < ActiveJob::Base
  queue_as :default

  def perform(tag_ids, order_ids, operation)
    orders = Order.where(id: order_ids)
    tags = OrderTag.where(id: tag_ids)

    case operation
    when 'add'
      tags.each do |tag|
        orders.each { |order| order.order_tags << tag }
      end
      $redis.set("add_or_remove_tags_job", "completed")
    when 'remove'
      tags.each do |tag|
        orders.each { |order| order.order_tags.destroy(tag) }
      end
      $redis.set("add_or_remove_tags_job", "completed")
    end
  rescue StandardError => e
    $redis.set("add_or_remove_tags_job", "failed")
    raise e
  end
end
