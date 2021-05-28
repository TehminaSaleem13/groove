class OrderItemBox < ActiveRecord::Base
  # attr_accessible :box_id, :item_qty, :order_item_id, :kit_id
  belongs_to :order_item, optional: true
  belongs_to :box, optional: true
end
