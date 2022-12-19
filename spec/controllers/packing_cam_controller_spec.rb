# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PackingCamController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    inv_wh = FactoryBot.create(:inventory_warehouse, is_default: true)
    @store = FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id)
  end

  describe 'Show Packing Cam' do
    let(:product) { FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id) }
    let(:order) { FactoryBot.create(:order, status: 'scanned', store: @store) }

    before do
      FactoryBot.create(:order_item, product_id: product.id, scanned_status: 'scanned', qty: 1, price: '10', row_total: '10', order: order, name: product.name)
      order.set_order_to_scanned_state(nil)
      order.packing_cams.create(url: 'abc', user: User.first)
    end

    context 'POST #show' do
      it 'success' do
        post :show, params: { email: order.email, order_number: order.increment_id }
        expect(response.status).to eq(200)
        result = JSON.parse response.body
        expect(result['status']).to be_truthy
      end

      it 'fails' do
        post :show, params: { email: order.email, order_number: nil }
        expect(response.status).to eq(200)
        result = JSON.parse response.body
        expect(result['status']).to be_falsy
      end
    end
  end
end
