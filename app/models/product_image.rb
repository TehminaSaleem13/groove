class ProductImage < ActiveRecord::Base
  belongs_to :product
  attr_accessible :image
end
