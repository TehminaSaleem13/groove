# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderShipping, type: :model do
  it 'order shipping should belongs to order' do
    order_shipping = described_class.reflect_on_association(:order)
    expect(order_shipping.macro).to eq(:belongs_to)
  end
end
