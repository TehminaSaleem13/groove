class OrderTagManager < Groovepacker::Utilities::Base
  include Connection

  BATCH_SIZE = 1000

  def initialize(tag_name, orders)
    @tag_name = tag_name
    @orders = orders
  end

  def add_tags
    GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 10 }, :tenant)
    if @tag_name.present?
      tag = OrderTag.find_by(name: @tag_name)
      if tag
        total_batches = (@orders.count.to_f / BATCH_SIZE).ceil

        # Store the total number of batches in Redis
        $redis.set("order_tagging_job:total_batches", total_batches)
        $redis.set("order_tagging_job:completed_batches", 0)

        @orders.find_in_batches(batch_size: BATCH_SIZE) do |order_batch|
          order_ids = order_batch.pluck(:id)
          if order_ids.size < BATCH_SIZE && @orders.length < BATCH_SIZE
            GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)

            perform_now(tag.id, order_ids, 'add')
          else
            OrderTaggingJob.perform_later(tag.id, order_ids, 'add', total_batches)
          end

        end
        { success: 'Tagging process started' }
      else
        { error: 'Tag not found' }
      end
    else
      { error: 'Tag name parameter is required' }
    end
  end

  def remove_tags
    GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 10 }, :tenant)
    if @tag_name.present?
      tags = OrderTag.where(name: @tag_name)
      if tags.any?
        total_batches = (@orders.count.to_f / BATCH_SIZE).ceil

        # Store the total number of batches in Redis
        $redis.set("order_tagging_job:total_batches", total_batches)
        $redis.set("order_tagging_job:completed_batches", 0)

        @orders.find_in_batches(batch_size: BATCH_SIZE) do |order_batch|
          order_ids = order_batch.pluck(:id)
          if order_ids.size < BATCH_SIZE && @orders.length < BATCH_SIZE
            GroovRealtime.emit('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)

            perform_now(tags.pluck(:id), order_ids, 'remove')
          else
            OrderTaggingJob.perform_later(tags.pluck(:id), order_ids, 'remove', total_batches)
          end

        end
        { success: 'Untagging process started' }
      else
        { error: 'Tags not found' }
      end
    else
      { error: 'Tag name parameter is required' }
    end
  end

  def perform_now(tag_ids, order_ids, operation)
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
