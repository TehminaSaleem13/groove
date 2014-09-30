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

  def self.get_temp_sku
    temp_skus = ProductSku.where("sku LIKE TSKU% ORDER BY sku")
    last_sku = temp_skus.last.sku

    
  end

end
