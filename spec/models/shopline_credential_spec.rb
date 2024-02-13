# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoplineCredential, type: :model do
  let(:push_location_id) { 123 }
  let(:pull_location_id) { 456 }
  let(:push_location) { { id: push_location_id, name: 'Push Location' } }
  let(:pull_location) { { id: pull_location_id, name: 'Pull Location' } }

  let(:store) do
    create(
      :store,
      name: 'Shopline Store',
      store_type: 'Shopline',
      inventory_warehouse: create(:inventory_warehouse, name: 'csv_inventory_warehouse'),
      status: true
    )
  end

  let(:shopline_credential) do
    create(
      :shopline_credential,
      shop_name: 'shopline',
      store: store,
      push_inv_location_id: push_location_id,
      pull_inv_location_id: pull_location_id
    )
  end

  describe 'Associations' do
    it 'belongs to store' do
      shopline_credential_association = described_class.reflect_on_association(:store)
      expect(shopline_credential_association.macro).to eq(:belongs_to)
    end
  end

  describe 'Callbacks' do
    describe 'after_save' do
      it 'triggers log_events' do
        expect(shopline_credential).to receive(:log_events)

        shopline_credential.save
      end
    end
  end

  describe '#get_status' do
    it 'returns the correct status string' do
      shopline_credential.shipped_status = true
      shopline_credential.unshipped_status = true

      status = shopline_credential.get_status

      # shipped status has priority on unshipped
      expect(status).to eq('shipped')
    end
  end

  describe 'Locations' do
    it 'returns the shopline locations' do
      locations = shopline_credential.locations

      expect(locations).not_to be_nil
      expect(locations.count).to be >= 1
    end

    it 'returns the pull inventory location' do
      location = shopline_credential.pull_inv_location

      expect(location).not_to be_nil
    end

    it 'returns the push inventory location' do
      location = shopline_credential.push_inv_location

      expect(location).not_to be_nil
    end
  end
end
