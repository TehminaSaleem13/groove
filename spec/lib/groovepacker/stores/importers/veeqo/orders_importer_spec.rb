# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::Stores::Importers::Veeqo::OrdersImporter do
  let(:store) { create(:store, :veeqo) }
  let(:credential) { store.veeqo_credential }
  let(:import_item) { double('ImportItem', store_id: store.id) }
  let(:handler) { { credential: credential, import_item: import_item, store_handle: double } }
  let(:service) { described_class.new(credential) }
  let!(:order) { create(:order, store_id: store.id, status: 'awaiting', increment_id: '1744', store_order_id: '123456') }

  before do
    allow(service).to receive(:get_handler).and_return(handler)
  end

  describe '#handle_merged_order' do
    let(:order_data) { { 'id'=> '123456','merged_to_id'=> '2' } }

    context 'when order have merged_to_id' do
      it 'returns true' do
        service.send(:init_common_objects)
        expect(service.send(:handle_merged_order, order_data)).to be true
        expect(Order.count).to eq(0)
      end
    end
  end
end