class ProductImage < ActiveRecord::Base
  belongs_to :product
  attr_accessible :image, :caption

  after_save :delete_empty

  def delete_empty
    if self.image.blank?
      self.destroy
    end
  end

end
