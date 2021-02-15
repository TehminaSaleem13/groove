require 'rails_helper'

RSpec.describe OrderException, type: :model do
  it 'order exception should belongs to order' do
    order_exception = OrderException.reflect_on_association(:order)
    expect(order_exception.macro).to eq(:belongs_to)
  end

  it 'order exception should belongs to user' do
    order_exception = OrderException.reflect_on_association(:user)
    expect(order_exception.macro).to eq(:belongs_to)
  end
end
