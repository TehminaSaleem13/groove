# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AmazonCredentials, type: :model do
  describe AmazonCredentials do
    it 'amazon credential should presence market place id' do
      amazon_credentials = described_class.create(marketplace_id: '')
      amazon_credentials.valid?
      amazon_credentials.errors.should have_key(:marketplace_id)
    end
  end

  describe AmazonCredentials do
    it 'amazon credential should presence merchent id' do
      amazon_credentials = described_class.create(merchant_id: '')
      amazon_credentials.valid?
      amazon_credentials.errors.should have_key(:merchant_id)
    end
  end

  it 'amzone credential should belongs to store' do
    amazon_credentials = described_class.reflect_on_association(:store)
    expect(amazon_credentials.macro).to eq(:belongs_to)
  end
end
