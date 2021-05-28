class ProductCat < ActiveRecord::Base
  belongs_to :product, optional: true
  # attr_accessible :category

  after_save :delete_empty

  def delete_empty
    if self.category.blank?
      self.destroy
    end
  end

end
