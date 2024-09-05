# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Box, type: :model do
  it 'box should have many order item boxes' do
    box = described_class.reflect_on_association(:order_item_boxes)
    expect(box.macro).to eq(:has_many)
  end

  it 'box should have many order items' do
    box = described_class.reflect_on_association(:order_items)
    expect(box.macro).to eq(:has_many)
  end

  describe Box do
    let(:store) { create(:store) }
    let!(:box) { described_class.create(name: 'productkit') }

    before do
      order = create(:order, store:)
      product = create(:product, store:)

      OrderItemBox.create(box_id: box.id, order_item: create(:order_item, order:, product:))
    end

    it 'dependent destroy' do
      expect { box.destroy }.to change(OrderItemBox, :count).by(-1)
    end
  end
end
