# frozen_string_literal: true

class ProductCat < ApplicationRecord
  belongs_to :product
  # attr_accessible :category

  after_save :delete_empty

  def delete_empty
    destroy if category.blank?
  end
end
