# frozen_string_literal: true

class ProductImage < ActiveRecord::Base
  belongs_to :product
  # attr_accessible :image, :caption

  after_save :delete_empty

  def delete_empty
    destroy if image.blank?
  end

  def self.update_image(params)
    image = ProductImage.find(params[:image][:id])
    image.added_to_receiving_instructions = params[:image][:added_to_receiving_instructions]
    image.image_note = params[:image][:image_note]
    return_val = image.save ? true : false
    return_val
  rescue StandardError
    false
  end
end
