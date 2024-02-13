# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  describe 'associations' do
    it 'belongs to an author (User)' do
      association = described_class.reflect_on_association(:author)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'requires an author' do
      api_key = described_class.new
      api_key.valid?

      expect(api_key.errors[:author]).to include("can't be blank")
    end
  end

  describe 'callbacks' do
    it 'generates token before validation' do
      api_key = build(:api_key, token: nil)
      api_key.valid?
      expect(api_key.token).to be_present
    end
  end

  describe 'scopes' do
    let!(:active_api_key) { create(:api_key) }
    let!(:deleted_api_key) { create(:api_key, deleted_at: Time.current) }
    let!(:expired_api_key) { create(:api_key, expires_at: 1.day.ago) }

    describe '.default_scope' do
      it 'excludes deleted and expired keys' do
        expect(described_class.all).to eq([active_api_key])
      end
    end

    describe '.deleted' do
      it 'returns only deleted keys' do
        expect(described_class.deleted).to eq([deleted_api_key])
      end
    end

    describe '.expired' do
      it 'returns only expired keys' do
        expect(described_class.expired).to eq([expired_api_key])
      end
    end
  end

  describe '.active' do
    it 'returns the first active API key' do
      active_api_key = create(:api_key)
      create(:api_key, expires_at: Date.tomorrow)

      expect(described_class.active).to eq(active_api_key)
    end
  end
end
