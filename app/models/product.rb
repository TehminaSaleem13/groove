class Product < ActiveRecord::Base
  belongs_to :store
  attr_accessible :name, :product_type, :store_product_id

  has_many :product_skus
  has_many :product_cats
  has_many :product_barcodes
  has_many :product_images
end
