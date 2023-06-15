require 'rails_helper'

RSpec.describe Groovepacker::Stores::Importers::Shippo::OrdersImporter do
  let(:order) do
    {
      'order_status' => 'SHIPPED',
      'transactions' => [
        { 'tracking_number' => 'ABC123' },
        { 'tracking_number' => 'DEF456' }
      ]
    }
  end
      
  describe '#order_tracking_number' do
    it 'returns the tracking number if order status is "SHIPPED" and tracking number exists' do
      response = described_class.new(order)
      expect(response.send(:order_tracking_number, order)).to eq('ABC123')
    end
  
    it 'returns nil if no tracking number exists' do
      order['transactions'] = []
      response = described_class.new(order)
      expect(response.send(:order_tracking_number, order)).to be_nil
    end
  end
end