class CartRow < ApplicationRecord
  belongs_to :cart

  validates :row_name, presence: true
  validates :row_count, numericality: { greater_than_or_equal_to: 0 }
end
