class ShopifyCredential < ActiveRecord::Base
  attr_accessible :access_token, :shop_name, :store_id

  belongs_to :store
end
