# frozen_string_literal: true

class ProductLot < ApplicationRecord
  # attr_accessible :lot_number, :product_id
  has_many :order_item_order_serial_product_lots
  belongs_to :product
end
