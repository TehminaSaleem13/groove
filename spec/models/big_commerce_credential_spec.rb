# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BigCommerceCredential, type: :model do
  it 'big commerce credential should belongs to store' do
    big_commerce_credential = described_class.reflect_on_association(:store)
    expect(big_commerce_credential.macro).to eq(:belongs_to)
  end
end
