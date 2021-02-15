require 'rails_helper'

RSpec.describe OrderItemKitProductScanTime, type: :model do
  it 'order item kit product scan time should belongs to order item kit product' do
    order_item_kit_product_scan_time = OrderItemKitProductScanTime.reflect_on_association(:order_item_kit_product)
    expect(order_item_kit_product_scan_time.macro).to eq(:belongs_to)
  end
end
