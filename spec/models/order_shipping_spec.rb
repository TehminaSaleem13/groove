require 'rails_helper'

RSpec.describe OrderShipping, type: :model do
  it 'order shipping should belongs to order' do
    order_shipping = OrderShipping.reflect_on_association(:order)
    expect(order_shipping.macro).to eq(:belongs_to)
  end
end
