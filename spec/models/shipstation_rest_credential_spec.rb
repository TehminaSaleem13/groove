require 'rails_helper'

RSpec.describe ShipstationCredential, type: :model do
  it 'shipstation rest  credential should presence  regular import range' do
    shipstation_rest_credential = ShipstationRestCredential.create(regular_import_range: '')
    shipstation_rest_credential.valid?
    shipstation_rest_credential.errors.should have_key(:regular_import_range)
  end

  it 'shipstation rest credential should belongs to store' do
    shipstation_rest_credential = ShipstationRestCredential.reflect_on_association(:store)
    expect(shipstation_rest_credential.macro).to eq(:belongs_to)
  end

  it 'return GPSCANNED tag name' do
    expect(ShipstationRestCredential.new.gp_scanned_tag_name).to eq('GPSCANNED')
  end
end
