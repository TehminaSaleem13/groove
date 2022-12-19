# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccessRestriction, type: :model do
  it 'Access restriction should has one tenant' do
    access_restriction = described_class.reflect_on_association(:tenant)
    expect(access_restriction.macro).to eq(:has_one)
  end
end
