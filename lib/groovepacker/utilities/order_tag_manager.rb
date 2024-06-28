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

          OrderTaggingJob.perform_later(tag.id, order_ids, 'add')
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
    if @tag_name.present?
      tags = OrderTag.where(name: @tag_name)
      if tags.any?
        @orders.find_in_batches(batch_size: 1000) do |order_batch|
          order_ids = order_batch.pluck(:id)

          OrderTaggingJob.perform_later(tags.pluck(:id), order_ids, 'remove')
        end
        { success: 'Untagging process started' }
      else
        { error: 'Tags not found' }
      end
    else
      { error: 'Tag name parameter is required' }
    end
  end
end
