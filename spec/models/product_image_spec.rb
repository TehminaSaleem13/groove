# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductImage, type: :model do
  it 'product image should belongs to product' do
    product_image = described_class.reflect_on_association(:product)
    expect(product_image.macro).to eq(:belongs_to)
  end
end
