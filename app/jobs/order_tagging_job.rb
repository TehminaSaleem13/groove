class OrderTaggingJob < ActiveJob::Base
  queue_as :default

  BATCH_SIZE = 1000

  def perform(tag_ids, order_ids, operation, total_batches)
    orders = Order.where(id: order_ids)
    tags = OrderTag.where(id: tag_ids)

    orders.find_in_batches(batch_size: BATCH_SIZE).with_index do |order_batch, index|
      if $redis.get("order_tagging_job:cancel") == "true"
        GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)
        return { error: 'Tagging process canceled' }
      end

      case operation
      when 'add'
        tags.each do |tag|
          order_batch.each { |order| order.order_tags << tag }
        end
      when 'remove'
        tags.each do |tag|
          order_batch.each { |order| order.order_tags.destroy(tag) }
        end
      end

      # Update the number of completed batches in Redis
      completed_batches = $redis.incr("order_tagging_job:completed_batches")

      # Broadcast progress after each batch is processed
      progress = (completed_batches.to_f / total_batches * 100).to_i
      if progress >= 90
        GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)
        
        return
      end
      GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: progress }, :tenant)
    end
  end
end
