class ProductBarcode < ActiveRecord::Base
  belongs_to :product
  attr_accessible :barcode
end
