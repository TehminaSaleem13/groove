class ProductKitSkus < ActiveRecord::Base
  belongs_to :product
  attr_accessible :sku
end
