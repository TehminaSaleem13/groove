class ProductSku < ActiveRecord::Base
  belongs_to :product
  belongs_to :order_item
  attr_accessible :purpose, :sku
  validates_uniqueness_of :sku

  after_save :delete_empty

  def delete_empty
    if self.sku.blank?
      self.destroy
    end
  end

  def self.get_temp_sku
    temp_skus = ProductSku.where("sku LIKE 'TSKU-%'").order(:sku)
    if temp_skus.length > 0
      next_sku = "TSKU-" + (get_last_temp_sku_token(temp_skus) + 1).to_s
    else
      next_sku = "TSKU-1"
    end
    next_sku
  end

  private

  def self.get_last_temp_sku_token(temp_skus)
    sku_tokens = []
    temp_skus.each do |sku|
      sku_tokens << sku.sku.split('-').last.to_i
    end
    sku_tokens.sort.last
  end

end
