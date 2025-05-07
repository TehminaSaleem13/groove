  class CartTote < ApplicationRecord
    belongs_to :cart_row

    validates :tote_id, presence: true

    validates :width, :height, :weight, presence: true

    attribute :width, :float, default: 0.0
    attribute :height, :float, default: 0.0
    attribute :weight, :float, default: 0.0
  end
  