class ShipstationCredential < ActiveRecord::Base
  attr_accessible :username, :password, :store_id
  validates_presence_of :username, :password

  belongs_to :store
end
