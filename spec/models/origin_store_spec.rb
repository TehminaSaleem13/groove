# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OriginStore, type: :model do
  describe 'associations' do
    it 'belongs to store' do
      expect(described_class.reflect_on_association(:store).macro).to eq(:belongs_to)
    end

    it 'has many orders with foreign key' do
      expect(described_class.reflect_on_association(:orders).macro).to eq(:has_many)
      expect(described_class.reflect_on_association(:orders).options[:foreign_key]).to eq(:origin_store_id)
    end
  end

  describe 'validations' do
    it 'validates presence of store_name' do
      origin_store = described_class.new(store_name: nil)
      expect(origin_store).not_to be_valid
      expect(origin_store.errors[:store_name]).to include("can't be blank")
    end

    it 'is valid with a non-empty store_name' do
      origin_store = described_class.new(store_name: 'Store Name')
      expect(origin_store).to be_valid
    end
  end
end
