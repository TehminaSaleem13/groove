# frozen_string_literal: true

require 'rails_helper'

describe Groovepacker::Stores::Importers::Shopify::Inventory do
  let(:inv_wh) { create(:inventory_warehouse, is_default: true) }
  let(:store) { create(:store, inventory_warehouse_id: inv_wh.id, store_type: 'Shopify') }

  describe '#inventory' do
    let(:params) { { select_all: true } }
    let(:credential) { create(:shopify_credential, store: store) }
    let(:result) { described_class.new(Apartment::Tenant.current, credential.store_id).pull_inventories }
    let(:shopify_product_variant_id) { '123123' }
    let(:inventory_quantity) { 5 }

    before do
      product = create(:product, :with_sku_barcode, store_id: store.id)
      create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: shopify_product_variant_id)
      allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:get_variant).with(shopify_product_variant_id).and_return(id: shopify_product_variant_id, inventory_quantity: inventory_quantity)
    end

    it 'Push Inventory' do
      expect(result).to include(Product.first)
    end
  end
end
