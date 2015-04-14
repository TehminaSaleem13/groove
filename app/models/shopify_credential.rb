class ShopifyCredential < ActiveRecord::Base
  attr_accessible :access_token, :shop_name, :store_id

  attr_writer :permission_url

  belongs_to :store

end
