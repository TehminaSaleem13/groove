require 'rails_helper'

RSpec.describe ProductCat, type: :model do
  it 'product cat should belongs to product' do
    product_cat = ProductCat.reflect_on_association(:product)
    expect(product_cat.macro).to eq(:belongs_to)
  end
end
