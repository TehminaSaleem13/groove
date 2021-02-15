require 'rails_helper'

RSpec.describe ProductLot, type: :model do
  it 'product lot has many order item order serial product_lots' do
    productlot = ProductLot.reflect_on_association(:order_item_order_serial_product_lots)
    expect(productlot.macro).to eq(:has_many)
  end

  it 'product lot belongs to product' do
    productlot = ProductLot.reflect_on_association(:product)
    expect(productlot.macro).to eq(:belongs_to)
  end
end
