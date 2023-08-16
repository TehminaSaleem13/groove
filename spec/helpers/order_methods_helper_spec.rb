# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderMethodsHelper do
  before do
    Groovepacker::SeedTenant.new.seed
    Tenant.create(name: Apartment::Tenant.current, test_tenant_toggle: test_tenant_toggle)
  end

  let(:test_tenant_toggle) { false }
  let(:inv_wh) { FactoryBot.create(:inventory_warehouse, is_default: true) }
  let(:store) { FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id) }
  let(:order) { FactoryBot.create(:order, store: store) }

  describe 'Shipstation Orders' do
    let(:store_order_id) { '123456789' }
    let(:store) { FactoryBot.create(:store, store_type: 'Shipstation API 2', name: 'Shipstation API 2', inventory_warehouse: inv_wh, status: true) }
    let!(:ss_credential) { FactoryBot.create(:shipstation_rest_credential, store: store) }
    let(:order) { FactoryBot.create(:order, status: 'scanned', store: store, store_order_id: store_order_id, ss_label_data: ss_label_data) }
    let(:ss_label_data) do
      {
        'orderId' => store_order_id,
        'carrierCode' => 'carrier',
        'serviceCode' => 'service',
        'packageCode' => 'package',
        'confirmation' => 'none',
        'shipDate' => 1.day.after.to_date,
        'postalCode' => 123_456,
        'weight' => { 'value' => 2.5, 'units' => 'pounds', 'WeightUnits' => 2 }
      }
    end

    describe '#create_label' do
      let(:ss_client) { double }

      before do
        allow(Groovepacker::ShipstationRuby::Rest::Client).to receive(:new).and_return(ss_client)
        allow(ss_client).to receive(:create_label_for_order).and_return('labelData' => 'base64data')
        allow(GroovS3).to receive(:create_pdf)
      end

      it 'creates a shipping label and stores the data' do
        expect_any_instance_of(OrderMethodsHelper).to receive(:store_shipping_label_data)

        result = order.create_label(ss_credential.id, ss_label_data)
        expect(result[:status]).to eq(true)
      end

      it 'does not return label data' do
        allow(ss_client).to receive(:create_label_for_order).and_return({error: 'error', error2: 'error 2'})
        result = order.create_label(ss_credential.id, ss_label_data)
        expect(result[:status]).to eq(false)
        expect(result[:error_messages]).to eq('error: error<br>error2: error 2')
      end

      it 'handles an error by setting status and error_messages' do
        allow(ShipstationRestCredential).to receive(:find).with(ss_credential.id).and_raise('StandardError')

        result = order.create_label(ss_credential.id, ss_label_data)
        expect(result[:status]).to eq(false)
        expect(result[:error_messages]).to eq('StandardError')
      end
    end

    describe '#check_valid_label_data' do
      context 'when data is valid' do
        it 'returns true' do
          expect(order.check_valid_label_data).to eq(true)
        end
      end

      context 'when data is invalid' do
        let(:ss_label_data) do
          {
            'orderId' => 123_456_789,
            'packageCode' => 'dummy_package',
            'confirmation' => 'none',
            'weight' => { 'value' => 2.5, 'units' => 'pounds', 'WeightUnits' => 2 }
          }
        end

        it 'returns false' do
          expect(order.check_valid_label_data).to eq(false)
        end
      end
    end

    describe '#store_shipping_label_data' do
      context 'when test tenant toggle is off (Live Tenant)' do
        it 'stores shipping label data' do
          expect { order.send(:store_shipping_label_data, store_order_id, 'url', 'shipment_id') }.to change(ShippingLabel, :count).by(1)
        end
      end

      context 'when test tenant toggle is on (Test Tenant)' do
        let(:test_tenant_toggle) { true }

        it 'does not store label data' do
          expect { order.send(:store_shipping_label_data, 'store_order_id', 'url', 'shipment_id') }.not_to change(ShippingLabel, :count)
        end
      end
    end
  end
end
