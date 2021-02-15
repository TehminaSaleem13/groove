require 'rails_helper'

RSpec.describe EbayCredentials, type: :model do
  it 'ebay credentials should belongs to store' do
    ebay_credentials = EbayCredentials.reflect_on_association(:store)
    expect(ebay_credentials.macro).to eq(:belongs_to)
  end
end
