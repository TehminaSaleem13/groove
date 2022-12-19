# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderItemOrderSerialProductLot, type: :model do
  it 'belongses to order item' do
    order_item_order_serial_product_lots = described_class.reflect_on_association(:order_item)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end

  it 'belongses to order serial' do
    order_item_order_serial_product_lots = described_class.reflect_on_association(:order_serial)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end

  it 'belongses to product lot' do
    order_item_order_serial_product_lots = described_class.reflect_on_association(:product_lot)
    expect(order_item_order_serial_product_lots.macro).to eq(:belongs_to)
  end
end
