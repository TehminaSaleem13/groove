class Cart < ApplicationRecord
  has_many :cart_rows, dependent: :destroy

  validates :cart_name, presence: true
  validates :number_of_totes, numericality: { greater_than_or_equal_to: 0 }
end
