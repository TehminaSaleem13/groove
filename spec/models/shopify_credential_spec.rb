require 'rails_helper'

RSpec.describe ShopifyCredential, type: :model do
  it 'shopify credential should belongs to store' do
    shopify_credential = ShopifyCredential.reflect_on_association(:store)
    expect(shopify_credential.macro).to eq(:belongs_to)
  end
end
