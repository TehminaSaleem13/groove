# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShipworksCredential, type: :model do
  it 'requires auth token' do
    shipworks = described_class.create(auth_token: '')
    shipworks.valid?
    shipworks.errors.should have_key(:auth_token)
  end

  describe 'presence of store id' do
    it 'store id should be present' do
      shipworks = described_class.create(store_id: '')
      shipworks.valid?
      shipworks.errors.should have_key(:store_id)
    end
  end

  describe 'uniq auth token' do
    let(:shipworks) { described_class.new }
    let(:shipworks1) { described_class.new }

    it 'has uniq auth token' do
      shipworks.auth_token = 'kapil123'
      shipworks1.auth_token = 'kapil123'
      expect(shipworks1).not_to be_valid
    end
  end

  it 'shipworks credential should belongs to store' do
    t = described_class.reflect_on_association(:store)
    expect(t.macro).to eq(:belongs_to)
  end
end
