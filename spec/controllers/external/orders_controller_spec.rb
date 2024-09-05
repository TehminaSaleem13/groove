# frozen_string_literal: true

require 'rails_helper'

RSpec.describe External::OrdersController, type: :controller do
  let!(:api_key) { FactoryBot.create(:api_key) }
  let!(:inv_wh) { FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse') }
  let!(:store) do
    FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
  end
  let!(:tenant) { Tenant.create(name: Apartment::Tenant.current, enable_developer_tools: true) }
  let(:order) { FactoryBot.create :order, store_id: store.id }

  before do
    Groovepacker::SeedTenant.new.seed

    request.accept = 'application/json'
    header = { 'Authorization' => 'Bearer ' + api_key.token }
    request.headers.merge! header
  end

  after do
    tenant.destroy
  end

  describe '#retrieve' do
    let(:increment_id) { order.increment_id }

    before do
      post :retrieve, params: { increment_id: }
    end

    context 'when order is found' do
      before do
        # Setting Order Attributes
        product = FactoryBot.create(:product, name: 'PRODUCT1')
        order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                      name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
        kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1,
                                                             kit_parsing: 'individual')
        productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
        kit.product_kit_skuss << productkitsku
        ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
        OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: productkitsku.id,
                                   scanned_status: 'scanned', scanned_qty: 1)
      end

      it 'returns order data' do
        expect(response.status).to be 200
        expect(json_response['order_number']).to eq(order.increment_id)
      end
    end

    context 'when order is not found' do
      let(:increment_id) { 999 }

      it 'returns not found' do
        expect(response.status).to be 404
        expect(json_response['error']).to eq('Order not found')
      end
    end
  end
end
