class ProductImage < ActiveRecord::Base
  belongs_to :product
  attr_accessible :image, :caption

  after_save :delete_empty

  def delete_empty
    if self.image.blank?
      self.destroy
    end
  end

  def self.update_image(params)
    image = ProductImage.find(params[:image][:id])
    image.added_to_receiving_instructions = params[:image][:added_to_receiving_instructions]
    image.image_note = params[:image][:image_note]
    image.save
  end

end
