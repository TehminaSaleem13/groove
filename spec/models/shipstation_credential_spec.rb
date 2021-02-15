require 'rails_helper'

RSpec.describe ShipstationCredential, type: :model do
  describe 'presence of username' do
    it ' shipstation should have username' do
      shipstation = ShipstationCredential.create(username: '')
      shipstation.valid?
      shipstation.errors.should have_key(:username)
    end
  end

  describe 'presence of password' do
    it 'shipstation should have password' do
      shipstation = ShipstationCredential.create(password: '')
      shipstation.valid?
      shipstation.errors.should have_key(:password)
    end
  end

  it 'shipstation should belongs to store' do
    shipstation = ShipstationCredential.reflect_on_association(:store)
    expect(shipstation.macro).to eq(:belongs_to)
  end
end
