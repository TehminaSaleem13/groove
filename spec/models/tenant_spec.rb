require 'rails_helper'
RSpec.describe Tenant, type: :model do
  describe 'Uniq tenant name' do
    let(:tenant) { Tenant.new }
    let(:tenant1) { Tenant.new }
    it 'should have uniq  tenant name' do
      tenant.name = 'kapiltesting'
      tenant1.name = 'kapiltest'
      expect(tenant1).to be_valid
    end
  end

  describe Tenant do
    it 'tenant should has one  subscription' do
      t = Tenant.reflect_on_association(:subscription)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Tenant do
    it 'tenant should has one  access restriction' do
      t = Tenant.reflect_on_association(:access_restriction)
      expect(t.macro).to eq(:has_one)
    end
  end
end
