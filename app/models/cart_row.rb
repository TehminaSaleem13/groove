class CartRow < ApplicationRecord
  belongs_to :cart
  has_many :cart_totes, dependent: :destroy

  attribute :default_width, :float, default: 0.0
  attribute :default_height, :float, default: 0.0
  attribute :default_weight, :float, default: 0.0

  validates :row_name, presence: true
  validates :row_count, numericality: { greater_than_or_equal_to: 0 }
  validates :default_width, :default_height, :default_weight, numericality: { greater_than_or_equal_to: 0 }
end
