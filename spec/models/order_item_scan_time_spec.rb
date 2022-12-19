# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderItemScanTime, type: :model do
  it 'order item scan time  should belongs to order_item' do
    order_item_scan_times = described_class.reflect_on_association(:order_item)
    expect(order_item_scan_times.macro).to eq(:belongs_to)
  end
end
