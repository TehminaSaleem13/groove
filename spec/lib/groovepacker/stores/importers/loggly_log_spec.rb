
# frozen_string_literal: true

require 'rails_helper'

describe Groovepacker::Stores::Importers::LogglyLog do
  let!(:tenant) { create(:tenant, name: Apartment::Tenant.current) }

  let!(:orders_response) { [ { id: 1, name: 'test order 1' }] }
  let!(:import_item) { }
  
  describe '.log_orders_response' do
    let!(:shipments_response) { { data: 'shipment data' } }
    let!(:shopify_store) { create(:store, :shopify) }
    let!(:store_name) { shopify_store&.store_type&.downcase&.gsub(/\s/, '_') }

    before do
      allow(Groovepacker::LogglyLogger).to receive(:log)
    end

    it 'logs orders response' do
      allow(described_class).to receive(:log_data).and_return({})

      described_class.log_orders_response(orders_response, shopify_store, import_item, shipments_response)
      expect(Groovepacker::LogglyLogger).to have_received(:log).with(any_args)
    end

    it 'merges shipments response if present' do
      allow(described_class).to receive(:log_data).and_return({ shipments: shipments_response })

      described_class.log_orders_response(orders_response, shopify_store, import_item, shipments_response)
      expect(Groovepacker::LogglyLogger).to have_received(:log).with(tenant.name, "#{store_name}_import-store_id-#{shopify_store.id}", { shipments: shipments_response })
    end
  end

  describe 'private methods' do
    let!(:store) { create(:store) }

    describe '.log_data' do
      it 'returns a hash' do
        described_class.instance_variable_set(:@store, store)
        expect(described_class.send(:log_data, [], nil)).to be_a(Hash)
      end
    end

    describe '.order_log_attributes' do
      it 'returns an array for Shipstation' do
        store.update(store_type: 'Shipstation API 2')
        described_class.instance_variable_set(:@store, store)
        expect(described_class.send(:order_log_attributes)).to be_an(Array)
      end

      it 'returns an array for Shopify' do
        store.update(store_type: 'Shopify')
        described_class.instance_variable_set(:@store, store)

        expect(described_class.send(:order_log_attributes)).to be_an(Array)
      end

      it 'returns an array for ShippingEasy' do
        store.update(store_type: 'ShippingEasy')
        described_class.instance_variable_set(:@store, store)
        expect(described_class.send(:order_log_attributes)).to be_an(Array)
      end

      it 'returns an empty array if other type ' do
        store.update(store_type: 'Shippo')
        described_class.instance_variable_set(:@store, store)
        expect(described_class.send(:order_log_attributes)).to eq([])
      end
    end
  end
end
