# frozen_string_literal: true

class OrderItemBox < ApplicationRecord
  # attr_accessible :box_id, :item_qty, :order_item_id, :kit_id
  belongs_to :order_item
  belongs_to :box
end
