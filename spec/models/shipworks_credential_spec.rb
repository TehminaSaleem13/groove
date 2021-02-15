require 'rails_helper'

RSpec.describe ShipworksCredential, type: :model do
  it 'should require auth token' do
    shipworks = ShipworksCredential.create(auth_token: '')
    shipworks.valid?
    shipworks.errors.should have_key(:auth_token)
  end

  describe 'presence of store id' do
    it 'store id should be present' do
      shipworks = ShipworksCredential.create(store_id: '')
      shipworks.valid?
      shipworks.errors.should have_key(:store_id)
    end
  end

  describe 'uniq auth token' do
    let(:shipworks) { ShipworksCredential.new }
    let(:shipworks1) { ShipworksCredential.new }
    it 'should have uniq auth token' do
      shipworks.auth_token = 'kapil123'
      shipworks1.auth_token = 'kapil123'
      expect(shipworks1).not_to be_valid
    end
  end

  it 'shipworks credential should belongs to store' do
    t = ShipworksCredential.reflect_on_association(:store)
    expect(t.macro).to eq(:belongs_to)
  end
end
