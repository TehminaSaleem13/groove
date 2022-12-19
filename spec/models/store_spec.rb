# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Store, type: :model do
  describe Store do
    it 'store should have many orders' do
      t = described_class.reflect_on_association(:orders)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Store do
    it 'store should have many  products' do
      t = described_class.reflect_on_association(:products)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Store do
    it 'store should have one magento credentials' do
      t = described_class.reflect_on_association(:magento_credentials)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one ebay credentials' do
      t = described_class.reflect_on_association(:ebay_credentials)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one amazon credentials' do
      t = described_class.reflect_on_association(:amazon_credentials)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one shipstation credentials' do
      t = described_class.reflect_on_association(:shipstation_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one shipstation  rest credentials' do
      t = described_class.reflect_on_association(:shipstation_rest_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one shipworks credential' do
      t = described_class.reflect_on_association(:shipworks_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one shopify credentials' do
      t = described_class.reflect_on_association(:shopify_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one ftp credential' do
      t = described_class.reflect_on_association(:ftp_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one big commerce credential' do
      t = described_class.reflect_on_association(:big_commerce_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one magento rest credential' do
      t = described_class.reflect_on_association(:magento_rest_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one shipping easy credential' do
      t = described_class.reflect_on_association(:shipping_easy_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should have one teapplix_credential' do
      t = described_class.reflect_on_association(:teapplix_credential)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Store do
    it 'store should belongs to inventory warehouse' do
      t = described_class.reflect_on_association(:inventory_warehouse)
      expect(t.macro).to eq(:belongs_to)
    end
  end

  it 'requires name' do
    store = described_class.create(name: '')
    store.valid?
    store.errors.should have_key(:name)
  end

  describe 'uniq name' do
    let(:store) { described_class.create(name: 'csv') }
    let(:store1) { described_class.create(name: 'csv') }

    it 'has uniq name' do
      expect(store1).not_to be_valid
    end
  end
end
