class BigCommerceCredential < ActiveRecord::Base
  attr_accessible :access_token, :shop_name, :store_hash, :store_id, :last_imported_at

  belongs_to :store
end
