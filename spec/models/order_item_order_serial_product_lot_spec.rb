require 'rails_helper'

RSpec.describe OrderItemOrderSerialProductLot, type: :model do
  it 'it should belongs  to order item' do
    order_item_order_serial_product_lots = OrderItemOrderSerialProductLot.reflect_on_association(:order_item)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end

  it 'it should belongs to order serial' do
    order_item_order_serial_product_lots = OrderItemOrderSerialProductLot.reflect_on_association(:order_serial)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end

  it 'it should belongs to product lot' do
    order_item_order_serial_product_lots = OrderItemOrderSerialProductLot.reflect_on_association(:product_lot)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end
end
