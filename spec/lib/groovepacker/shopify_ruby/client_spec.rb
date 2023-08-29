# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::ShopifyRuby::Client do
  let(:shopify_credential) { create(:store, :shopify).shopify_credential }
  let(:client) { described_class.new(shopify_credential) }

  describe '#inventory_levels' do
    subject(:inventory_levels) { client.inventory_levels(location_id) }

    let(:location_id) { 123 }
    let(:inv_level1) { { id: 123, inventory_item_id: 123, available: 2 }.as_json }
    let(:inv_level2) { { id: 456, inventory_item_id: 456, available: 1 }.as_json }

    context 'when success' do
      let(:http_response) { [inv_level1, inv_level2] }

      before do
        allow(ShopifyAPI::InventoryLevel).to receive(:all).and_return(http_response)
      end

      it 'returns inventory_levels' do
        expect(inventory_levels).to match_array(http_response)
      end
    end

    context 'when failure' do
      before do
        allow(ShopifyAPI::Location).to receive(:all).and_raise('http_response')
      end

      it 'returns []' do
        expect(inventory_levels).to be_a(Array)
        expect(inventory_levels).to be_empty
      end
    end
  end

  describe '#locations' do
    subject(:locations) { client.locations }

    let(:location1) { { id: 123, name: 'LOC 1' }.as_json }
    let(:location2) { { id: 456, name: 'LOC 2' }.as_json }

    context 'when success' do
      let(:http_response) { [location1, location2] }

      before do
        allow(ShopifyAPI::Location).to receive(:all).and_return(http_response)
      end

      it 'returns locations' do
        expect(locations).to match_array(http_response)
      end
    end

    context 'when failure' do
      before do
        allow(ShopifyAPI::Location).to receive(:all).and_raise('http_response')
      end

      it 'returns []' do
        expect(locations).to be_a(Array)
        expect(locations).to be_empty
      end
    end
  end
end
