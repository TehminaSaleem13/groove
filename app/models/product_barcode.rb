class ProductBarcode < ActiveRecord::Base
  belongs_to :product
  belongs_to :order_item
  attr_accessible :barcode
  validates_uniqueness_of :barcode
  after_save :delete_empty

  def delete_empty
    destroy if barcode.blank?
  end

  def self.generate_barcode_from_sku(sku)
    product = sku.product
    return if product.try(:product_barcodes).present?
    if product.try(:is_intangible)
      product_barcode = product.product_barcodes.new
      product_barcode.barcode = product.primary_sku
      product_barcode.save
    end
  end
end
