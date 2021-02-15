require 'rails_helper'

RSpec.describe OrderItemKitProduct, type: :model do
  it 'order item kit product should belongs to order item' do
    order_item_kit_product = OrderItemKitProduct.reflect_on_association(:order_item)
    expect(order_item_kit_product.macro).to eq(:belongs_to)
  end

  it 'order item kit product should belongs to product kit skus' do
    order_item_kit_product = OrderItemKitProduct.reflect_on_association(:product_kit_skus)
    expect(order_item_kit_product.macro).to eq(:belongs_to)
  end

  it 'order item kit product should have many order item kit product scan times' do
    order_item_kit_product = OrderItemKitProduct.reflect_on_association(:order_item_kit_product_scan_times)
    expect(order_item_kit_product.macro).to eq(:has_many)
  end
end
