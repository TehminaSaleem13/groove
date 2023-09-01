# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::Orders::Verification::CheckUnscanned do
  subject { described_class.new(tenant, options) }

  let(:tenant) { Apartment::Tenant.current }
  let(:store) { create(:store, :csv) }
  let(:order_status) { 'awaiting' }
  let(:order) { create(:order, increment_id: 'Test Verify Order', status: order_status, store: store) }
  let(:options) do
    {
      order_id: order.id,
      request_ip: '127.0.0.1',
      current_user: 'username',
      app_url: 'app_url'
    }
  end

  describe '#call' do
    before do
      allow(HTTParty).to receive(:post).and_return(true)
    end

    context 'when order is scanned' do
      let(:order_status) { 'scanned' }

      it 'does not send message to slack' do
        expect(HTTParty).not_to receive(:post)
        subject.call
      end
    end

    context 'when order is unscanned' do
      it 'send message to slack' do
        expect(HTTParty).to receive(:post)
        subject.call
      end
    end
  end
end
