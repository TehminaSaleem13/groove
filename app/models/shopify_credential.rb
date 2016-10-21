class ShopifyCredential < ActiveRecord::Base
  attr_accessible :access_token, :shop_name, :store_id, :last_imported_at

  attr_writer :permission_url

  belongs_to :store

end
