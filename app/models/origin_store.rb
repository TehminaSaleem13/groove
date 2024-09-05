# frozen_string_literal: true

class OriginStore < ApplicationRecord
  belongs_to :store, optional: true
  has_many :orders

  validates :store_name, presence: true, allow_blank: false
end
