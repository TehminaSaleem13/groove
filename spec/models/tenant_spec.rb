# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Tenant, type: :model do
  describe 'Uniq tenant name' do
    let(:tenant) { described_class.new }
    let(:tenant1) { described_class.new }

    it 'has uniq tenant name' do
      tenant.name = 'kapiltesting'
      tenant1.name = 'kapiltest'
      expect(tenant1).to be_valid
    end
  end

  describe Tenant do
    it 'tenant should has one  subscription' do
      t = described_class.reflect_on_association(:subscription)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Tenant do
    it 'tenant should has one  access restriction' do
      t = described_class.reflect_on_association(:access_restriction)
      expect(t.macro).to eq(:has_one)
    end
  end
end
