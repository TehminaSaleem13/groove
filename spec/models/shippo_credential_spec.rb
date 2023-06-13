require 'rails_helper'

RSpec.describe ShippoCredential, type: :model do
  describe '#get_active_statuses' do
    let(:shippo_credentials) { described_class.new }

    context 'when import_paid? is true' do
      before do
        allow(shippo_credentials).to receive(:import_paid?).and_return(true)
      end

      it 'includes "PAID" in the statuses array' do
        expect(shippo_credentials.get_active_statuses).to include('PAID')
      end
    end

    context 'when import_awaitpay? is true' do
      before do
        allow(shippo_credentials).to receive(:import_awaitpay?).and_return(true)
      end

      it 'includes "AWAITPAY" in the statuses array' do
        expect(shippo_credentials.get_active_statuses).to include('AWAITPAY')
      end
    end

    context 'when import_partially_fulfilled? is true' do
      before do
        allow(shippo_credentials).to receive(:import_partially_fulfilled?).and_return(true)
      end

      it 'includes "PARTIALLY_FULFILLED" in the statuses array' do
        expect(shippo_credentials.get_active_statuses).to include('PARTIALLY_FULFILLED')
      end
    end

    context 'when import_shipped? is true' do
      before do
        allow(shippo_credentials).to receive(:import_shipped?).and_return(true)
      end

      it 'includes "SHIPPED" in the statuses array' do
        expect(shippo_credentials.get_active_statuses).to include('SHIPPED')
      end
    end

    context 'when import_any? is true' do
      before do
        allow(shippo_credentials).to receive(:import_any?).and_return(true)
      end

      it 'includes all statuses in the statuses array' do
        expect(shippo_credentials.get_active_statuses).to contain_exactly('PAID', 'AWAITPAY', 'PARTIALLY_FULFILLED', 'SHIPPED')
      end
    end

    context 'when no import status is true' do
      before do
        allow(shippo_credentials).to receive(:import_paid?).and_return(false)
        allow(shippo_credentials).to receive(:import_awaitpay?).and_return(false)
        allow(shippo_credentials).to receive(:import_partially_fulfilled?).and_return(false)
        allow(shippo_credentials).to receive(:import_shipped?).and_return(false)
        allow(shippo_credentials).to receive(:import_any?).and_return(false)
      end

      it 'returns an empty array' do
        expect(shippo_credentials.get_active_statuses).to be_empty
      end
    end
  end
end