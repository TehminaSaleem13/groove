# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopifyCredential, type: :model do
  it 'shopify credential should belongs to store' do
    shopify_credential = described_class.reflect_on_association(:store)
    expect(shopify_credential.macro).to eq(:belongs_to)
  end

  it 'After Commit Log Events' do
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    store = FactoryBot.create(:store, name: 'shopify', store_type: 'Shopify', inventory_warehouse: inv_wh, status: true)
    shopify_credential = described_class.create(shop_name: nil, access_token: nil, store_id: store.id, created_at: '2021-03-03 18:53:04', updated_at: '2021-03-03 18:54:12', last_imported_at: nil, shopify_status: 'open', shipped_status: false, unshipped_status: false, partial_status: false, product_last_import: nil, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false, import_updated_sku: false, updated_sku_handling: 'add_to_existing', permit_shared_barcodes: false)
    shopify_credential.run_callbacks :commit
    expect(shopify_credential.log_events).to eq(true)
  end

  it 'Get Status' do
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    store = FactoryBot.create(:store, name: 'shopify', store_type: 'Shopify', inventory_warehouse: inv_wh, status: true)
    shopify_credential = described_class.create(shop_name: nil, access_token: nil, store_id: store.id, created_at: '2021-03-03 18:53:04', updated_at: '2021-03-03 18:54:12', last_imported_at: nil, shopify_status: 'open', shipped_status: true, unshipped_status: false, partial_status: false, product_last_import: nil, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false, import_updated_sku: false, updated_sku_handling: 'add_to_existing', permit_shared_barcodes: false)
    shopify_credential.run_callbacks :commit
    expect(shopify_credential.get_status).to eq('shipped%2C')
  end
end
