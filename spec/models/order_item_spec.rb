# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  it 'order item should belongs to order' do
    order_item = described_class.reflect_on_association(:order)
    expect(order_item.macro).to eq(:belongs_to)
  end

  it 'order item should belongs to product' do
    order_item = described_class.reflect_on_association(:product)
    expect(order_item.macro).to eq(:belongs_to)
  end

  it 'order item should have many order_item_boxes' do
    order_item = described_class.reflect_on_association(:order_item_boxes)
    expect(order_item.macro).to eq(:has_many)
  end

  it 'order item should have many boxes' do
    order_item = described_class.reflect_on_association(:boxes)
    expect(order_item.macro).to eq(:has_many)
  end

  it 'order item should have many order item kit product' do
    order_item = described_class.reflect_on_association(:order_item_kit_products)
    expect(order_item.macro).to eq(:has_many)
  end

  it 'order item should have many order item order serial product lots' do
    order_item = described_class.reflect_on_association(:order_item_order_serial_product_lots)
    expect(order_item.macro).to eq(:has_many)
  end

  it 'order item should have many order item scan times' do
    order_item = described_class.reflect_on_association(:order_item_scan_times)
    expect(order_item.macro).to eq(:has_many)
  end

  it 'order item should  have one product barcode' do
    order_item = described_class.reflect_on_association(:product_barcode)
    expect(order_item.macro).to eq(:has_one)
  end

  it 'order item should have one product sku' do
    order_item = described_class.reflect_on_association(:product_sku)
    expect(order_item.macro).to eq(:has_one)
  end
end
