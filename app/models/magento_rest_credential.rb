class MagentoRestCredential < ActiveRecord::Base
  attr_accessible :api_key, :api_secret, :host, :import_categories, :import_images, :store_id, :access_token
  belongs_to :product
end
