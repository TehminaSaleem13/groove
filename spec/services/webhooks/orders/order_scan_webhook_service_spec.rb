require 'rails_helper'

RSpec.describe Webhooks::Orders::OrderScanWebhookService do
  describe '.trigger_scanned_order_webhooks' do
    let!(:tenant_name) { Apartment::Tenant.current }
    let(:tenant) { create(name: tenant_name) }
    let!(:inv_wh)  { create(:inventory_warehouse, is_default: true) }
    let!(:store) { create(:store, inventory_warehouse: inv_wh) }
    let!(:order) { create(:order, status: 'scanned', store: store) }

    context 'when there are scanned orders with valid webhooks' do
      let!(:webhook1) { create(:groovepacker_webhook) }
      let!(:webhook2) { create(:groovepacker_webhook) }
      let(:order_serializer) { instance_double(External::OrderSerializer) }
      let(:order_data) { { id: 1, name: order.firstname } }

      before do
        allow(External::OrderSerializer).to receive(:new).with(order).and_return(order_serializer)
        allow(order_serializer).to receive(:serializable_hash).and_return(order_data)
        stub_request(:post, webhook1.url).to_return(status: 200, body: '{"success": true}', headers: {})
        stub_request(:post, webhook2.url).to_return(status: 200, body: '{"success": true}', headers: {})
      end

      it 'triggers delayed jobs for each webhook' do
        expect(Webhooks::Orders::OrderScanWebhookService).to receive(:delay)
          .twice
          .and_return(double(run: true))

        described_class.trigger_scanned_order_webhooks(order.id)
      end
    end

    context 'when there are no webhooks' do
      it 'does not trigger any delayed jobs' do
        expect(Webhooks::Orders::OrderScanWebhookService).not_to receive(:delay)
        described_class.trigger_scanned_order_webhooks(order.id)
      end
    end
  end
end
