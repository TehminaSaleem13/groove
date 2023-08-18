# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::ShopifyRuby::Client do
  let(:shopify_credential) { create(:store, :shopify).shopify_credential }
  let(:client) { described_class.new(shopify_credential) }

  describe '#inventory_levels' do
    subject(:inventory_levels) { client.inventory_levels(location_id) }

    let(:location_id) { 123 }
    let(:inv_level1) { { id: 123, inventory_item_id: 123, available: 2 }.with_indifferent_access }
    let(:inv_level2) { { id: 456, inventory_item_id: 456, available: 1 }.with_indifferent_access }

    before do
      allow(HTTParty).to receive(:get).and_return(http_response)
    end

    context 'when success' do
      let(:http_response) { { inventory_levels: [inv_level1, inv_level2] }.with_indifferent_access }

      it 'returns inventory_levels' do
        expect(inventory_levels).to match_array(http_response[:inventory_levels])
      end
    end

    context 'when failure' do
      let(:http_response) { { 'errors': 'Not Found' } }

      it 'returns []' do
        expect(inventory_levels).to be_a(Array)
        expect(inventory_levels).to be_empty
      end
    end
  end

  describe '#locations' do
    subject(:locations) { client.locations }

    let(:location1) { { id: 123, name: 'LOC 1' }.with_indifferent_access }
    let(:location2) { { id: 456, name: 'LOC 2' }.with_indifferent_access }

    before do
      allow(HTTParty).to receive(:get).and_return(http_response)
    end

    context 'when success' do
      let(:http_response) { { locations: [location1, location2] }.with_indifferent_access }

      it 'returns locations' do
        expect(locations).to match_array(http_response[:locations])
      end
    end

    context 'when failure' do
      let(:http_response) { { 'errors': 'Not Found' } }

      it 'returns []' do
        expect(locations).to be_a(Array)
        expect(locations).to be_empty
      end
    end
  end
end
