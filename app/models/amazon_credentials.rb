class AmazonCredentials < ActiveRecord::Base
  
  attr_accessible :marketplace_id, :merchant_id, :productmarketplace_id, :productmerchant_id,
  :import_products, :import_images

  validates_presence_of :marketplace_id, :merchant_id, :productmarketplace_id, :productmerchant_id

  belongs_to :store
end
