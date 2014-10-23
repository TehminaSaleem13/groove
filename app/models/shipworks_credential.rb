class ShipworksCredential < ActiveRecord::Base
  attr_accessible :auth_token, :store_id

  validates_presence_of :auth_token
  validates_presence_of :store_id

  validates_uniqueness_of :auth_token

  attr_accessible :auth_token, :store

  belongs_to :store
end
