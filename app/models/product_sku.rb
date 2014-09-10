class ProductSku < ActiveRecord::Base
  belongs_to :product
  attr_accessible :purpose, :sku
  validates_uniqueness_of :sku

  after_save :delete_empty

  def delete_empty
    if self.sku.blank?
      self.destroy
    end
  end

end
