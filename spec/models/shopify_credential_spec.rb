# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopifyCredential, type: :model do
  let(:push_location_id) { 123 }
  let(:pull_location_id) { 456 }
  let(:push_location) { { 'id' => push_location_id, 'name' => 'Push Location' } }
  let(:pull_location) { { 'id' => pull_location_id, 'name' => 'Pull Location' } }

  let(:store) do
    create(
      :store,
      name: 'shopify',
      store_type: 'Shopify',
      inventory_warehouse: create(:inventory_warehouse, name: 'csv_inventory_warehouse'),
      status: true
    )
  end

  let(:shopify_credential) do
    create(
      :shopify_credential,
      shop_name: 'shopify',
      store: store,
      push_inv_location_id: push_location_id,
      pull_inv_location_id: pull_location_id
    )
  end

  before do
    allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:locations).and_return([push_location, pull_location])
  end

  describe 'Associations' do
    it 'belongs to store' do
      shopify_credential_association = described_class.reflect_on_association(:store)
      expect(shopify_credential_association.macro).to eq(:belongs_to)
    end
  end

  describe 'Callbacks' do
    describe 'after_save' do
      context 'when webhook_order_import changes from true to false' do
        it 'calls de_activate_webhooks on ShopifyWebhookService' do
          shopify_credential = create(:shopify_credential, webhook_order_import: true)

          expect_any_instance_of(Webhooks::Shopify::ShopifyWebhookService).to receive(:de_activate_webhooks)

          shopify_credential.update(webhook_order_import: false)
        end
      end

      context 'when webhook_order_import changes from false to true' do
        it 'calls activate_webhooks on ShopifyWebhookService' do
          shopify_credential = create(:shopify_credential, webhook_order_import: false)

          expect_any_instance_of(Webhooks::Shopify::ShopifyWebhookService).to receive(:activate_webhooks)

          shopify_credential.update(webhook_order_import: true)
        end
      end
    end

    it 'triggers log_events' do
      expect(shopify_credential).to receive(:log_events)

      shopify_credential.save
    end
  end

  describe '#get_status' do
    it 'returns the correct status string' do
      shopify_credential.shipped_status = true
      shopify_credential.unshipped_status = true

      status = shopify_credential.get_status

      expect(status).to eq('shipped%2Cunshipped%2C')
    end
  end

  describe '#push_inv_location' do
    it 'returns the push inventory location' do
      result = shopify_credential.push_inv_location

      expect(result['name']).to eq('Push Location')
    end
  end

  describe '#pull_inv_location' do
    it 'returns the pull inventory location' do
      result = shopify_credential.pull_inv_location

      expect(result['name']).to eq('Pull Location')
    end
  end

  describe '#locations' do
    it 'returns locations' do
      expect(shopify_credential.locations).to match_array([push_location, pull_location])
    end
  end

  describe '#activate_webhooks' do
    it 'calls activate_webhooks on ShopifyWebhookService' do
      webhook_service = instance_double(Webhooks::Shopify::ShopifyWebhookService)
      allow(Webhooks::Shopify::ShopifyWebhookService).to receive(:new).with(shopify_credential).and_return(webhook_service)
      allow(shopify_credential).to receive(:saved_change_to_webhook_order_import?).and_return(true)

      expect(webhook_service).to receive(:activate_webhooks)

      shopify_credential.activate_webhooks
    end
  end

  describe '#de_activate_webhooks' do
    it 'calls de_activate_webhooks on ShopifyWebhookService' do
      webhook_service = instance_double(Webhooks::Shopify::ShopifyWebhookService)
      allow(Webhooks::Shopify::ShopifyWebhookService).to receive(:new).with(shopify_credential).and_return(webhook_service)
      allow(shopify_credential).to receive(:saved_change_to_webhook_order_import?).and_return(true)

      expect(webhook_service).to receive(:de_activate_webhooks)

      shopify_credential.de_activate_webhooks
    end
  end
end
