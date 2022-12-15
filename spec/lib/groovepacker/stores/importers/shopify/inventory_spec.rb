require 'rails_helper'

describe Groovepacker::Stores::Importers::Shopify::Inventory do
  let(:inv_wh) { create(:inventory_warehouse, is_default: true) }
  let(:store) { create(:store, inventory_warehouse_id: inv_wh.id, store_type: 'Shopify') }

  describe '#inventory' do
    let(:params) { { select_all: true } }
    let(:credential) { create(:shopify_credential, store: store) }
    let(:client) { Groovepacker::ShopifyRuby::Client.new(credential) }
    let(:result) { Groovepacker::Stores::Importers::Shopify::Inventory.new(credential: credential, store_handle: client).pull_inventories }
    let(:shopify_product_variant_id) { '123123' }
    let(:inventory_quantity) { 5 }

    before do
      product = create(:product, :with_sku_barcode, store_id: store.id)
      create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: shopify_product_variant_id)
      allow(client).to receive(:get_variant).with(shopify_product_variant_id).and_return(id: shopify_product_variant_id, inventory_quantity: inventory_quantity)
    end

    it 'Push Inventory' do
      expect(result).to include(Product.first)
    end
  end
end
