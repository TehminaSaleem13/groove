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
    when 'remove'
      tags.each do |tag|
        orders.each { |order| order.order_tags.destroy(tag) }
      end
    end
  end
end
