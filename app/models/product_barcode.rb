class ProductBarcode < ActiveRecord::Base
  belongs_to :product
  belongs_to :order_item
  attr_accessible :barcode
  validates_uniqueness_of :barcode
  after_save :delete_empty

  def delete_empty
    if self.barcode.blank?
      self.destroy
    end
  end
end
