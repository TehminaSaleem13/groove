# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductKitSkus, type: :model do
  it 'product kit sku  should belongs to product' do
    productkitsku = described_class.reflect_on_association(:product)
    expect(productkitsku.macro).to eq(:belongs_to)
  end

  it 'product kit sku should has many order item  kit product' do
    productkitsku = described_class.reflect_on_association(:order_item_kit_products)
    expect(productkitsku.macro).to eq(:has_many)
  end

  it 'product kit sku should belongs to option product' do
    productkitsku = described_class.reflect_on_association(:option_product)
    expect(productkitsku.macro).to eq(:belongs_to)
  end
end
