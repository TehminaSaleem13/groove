# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderItemBox, type: :model do
  it 'order item box should belongs to order item' do
    order_item_box = described_class.reflect_on_association(:order_item)
    expect(order_item_box.macro).to eq(:belongs_to)
  end

  it 'order item box should belongs to box' do
    order_item_box = described_class.reflect_on_association(:box)
    expect(order_item_box.macro).to eq(:belongs_to)
  end
end
