require 'rails_helper'

RSpec.describe ShippingEasyCredential, type: :model do
  it 'shipping easy credential should belongs to store' do
    shipping_easy_credential = ShippingEasyCredential.reflect_on_association(:store)
    expect(shipping_easy_credential.macro).to eq(:belongs_to)
  end
end
