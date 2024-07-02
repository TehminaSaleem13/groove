# lib/order_tag_manager.rb

class OrderTagManager < Groovepacker::Utilities::Base
  include Connection

  def initialize(tag_name, orders)
    @tag_name = tag_name
    @orders = orders
  end

  def add_tags
    if @tag_name.present?
      tag = OrderTag.find_by(name: @tag_name)
      if tag
        @orders.find_in_batches(batch_size: 1000) do |order_batch|
          order_ids = order_batch.pluck(:id)
          if order_ids.size < 100
            perform_now(tag.id, order_ids, 'add')
          else
            OrderTaggingJob.perform_later(tag.id, order_ids, 'add')
          end
        end
        $redis.set("add_or_remove_tags_job", "in_progress")
        { success: 'Tagging process started' }
      else
        { error: 'Tag not found' }
      end
    else
      { error: 'Tag name parameter is required' }
    end
  end

  def remove_tags
    if @tag_name.present?
      tags = OrderTag.where(name: @tag_name)
      if tags.any?
        @orders.find_in_batches(batch_size: 1000) do |order_batch|
          order_ids = order_batch.pluck(:id)
          if order_ids.size < 100
            perform_now(tags.pluck(:id), order_ids, 'remove')
          else
            OrderTaggingJob.perform_later(tags.pluck(:id), order_ids, 'remove')
          end
        end
        $redis.set("add_or_remove_tags_job", "in_progress")
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
