class ProductBarcode < ActiveRecord::Base
  belongs_to :product
  belongs_to :order_item
  # attr_accessible :barcode, :product_id, :packing_count, :is_multipack_barcode
  validates_uniqueness_of :barcode
  after_save :delete_empty
  before_save :update_packing_count
  # after_save :update_multibarcode

  def delete_empty
    destroy if barcode.blank?
  end

  def self.generate_barcode_from_sku(sku)
    product = sku.product
    return if product.try(:product_barcodes).present?
    if product.try :is_intangible
      product_barcode = product.product_barcodes.new
      product_barcode.barcode = product.primary_sku
      product_barcode.save
    end
  end

  def self.get_shared_barcode_products(barcode)
    shared_product_data = []
    products = ProductBarcode.includes(:product).where(barcode: barcode).map(&:product)
    products.each do |product|
      shared_product_data << { name: product.name, sku: product.product_skus.map(&:sku).join(', ') }
    end
    shared_product_data
  end

  def update_packing_count
    self.is_multipack_barcode = true
    self.packing_count = 1 if self.packing_count.blank? && self.barcode.present?
  end

  def update_multibarcode
    self.update_column(:is_multipack_barcode, true)
  end
end
