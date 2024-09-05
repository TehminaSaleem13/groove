# frozen_string_literal: true

class ShipstationCredential < ApplicationRecord
  # attr_accessible :username, :password, :store_id
  validates_presence_of :username, :password

  belongs_to :store
end
