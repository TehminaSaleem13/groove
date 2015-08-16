class AmazonCredentials < ActiveRecord::Base

  attr_accessible :marketplace_id, :merchant_id, :import_products, :import_images, :show_product_weight, :show_shipping_weight

  validates_presence_of :marketplace_id, :merchant_id

  belongs_to :store
end
