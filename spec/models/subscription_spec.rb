require 'rails_helper'

RSpec.describe Subscription, type: :model do
  it 'subscription should belongs to tenant' do
    subcription = Subscription.reflect_on_association(:tenant)
    expect(subcription.macro).to eq(:belongs_to)
  end

  it 'subscription should have many transcations' do
    subcription = Subscription.reflect_on_association(:transactions)
    expect(subcription.macro).to eq(:has_many)
  end
end
