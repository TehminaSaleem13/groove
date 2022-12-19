# frozen_string_literal: true

class Box < ActiveRecord::Base
  # attr_accessible :name, :order_id
  has_many :order_item_boxes, dependent: :destroy
  has_many :order_items, through: :order_item_boxes
end
