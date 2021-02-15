require 'rails_helper'

RSpec.describe Box, type: :model do
  it 'box should have many order item boxes' do
    box = Box.reflect_on_association(:order_item_boxes)
    expect(box.macro).to eq(:has_many)
  end

  it 'box should have many order items' do
    box = Box.reflect_on_association(:order_items)
    expect(box.macro).to eq(:has_many)
  end

  describe Box do
    box = Box.create(name: 'productkit')
    OrderItemBox.create(box_id: box.id)

    it 'dependent destroy' do
      expect { box.destroy }.to change { OrderItemBox.count }.by(-1)
    end
  end
end
