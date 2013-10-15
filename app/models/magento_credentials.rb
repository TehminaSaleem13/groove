class MagentoCredentials < ActiveRecord::Base
  
  attr_accessible :host, :password, :username, :api_key, :import_products, :import_images 

  validates_presence_of :host, :password,:username, :api_key

  belongs_to :store

end