class ShipstationRestCredential < ActiveRecord::Base
  attr_accessible :api_key, :api_secret, :store_id
  validates_presence_of :api_key, :api_secret

  belongs_to :store

end

