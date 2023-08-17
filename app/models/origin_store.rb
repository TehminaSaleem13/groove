# frozen_string_literal: true

class OriginStore < ApplicationRecord
  belongs_to :store
  has_many :orders, foreign_key: :origin_store_id

  validates :store_name, presence: true, allow_blank: false
end
