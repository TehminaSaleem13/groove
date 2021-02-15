require 'rails_helper'

RSpec.describe AccessRestriction, type: :model do
  it 'Access restriction should has one tenant' do
    access_restriction = AccessRestriction.reflect_on_association(:tenant)
    expect(access_restriction.macro).to eq(:has_one)
  end
end
