class ProductSku < ActiveRecord::Base
  belongs_to :product
  attr_accessible :purpose, :sku
end
