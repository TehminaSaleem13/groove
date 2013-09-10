class ProductCat < ActiveRecord::Base
  belongs_to :product
  attr_accessible :category
end
