# frozen_string_literal: true

require 'rails_helper'

describe Groovepacker::Stores::Exporters::Shopify::Inventory do
  subject { described_class.new(tenant.name, store.id) }

  let(:tenant) { create(:tenant, name: Apartment::Tenant.current) }
  let(:shopify_credential) { build(:shopify_credential) }
  let(:store) { create(:store, :shopify, shopify_credential: shopify_credential) }

  describe '#push_inventories' do
    before do
      shopify_product_variant_id = 12_345_678_901_234
      product = create(:product, :with_sku_barcode, store_id: store.id)
      create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: shopify_product_variant_id)
      allow(CsvExportMailer).to receive(:send_push_pull_inventories_products).and_return(double(deliver: true))
    end

    it 'triggers email' do
      VCR.use_cassette('shopify/push_inventories') do
        subject.push_inventories
      end

      expect(CsvExportMailer).to have_received(:send_push_pull_inventories_products)
    end
  end
end
