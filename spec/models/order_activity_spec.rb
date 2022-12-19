# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderActivity, type: :model do
  it 'order activity should belongs to order' do
    order_activity = described_class.reflect_on_association(:order)
    expect(order_activity.macro).to eq(:belongs_to)
  end

  it 'order activity should belongs to user' do
    order_activity = described_class.reflect_on_association(:user)
    expect(order_activity.macro).to eq(:belongs_to)
  end
end
