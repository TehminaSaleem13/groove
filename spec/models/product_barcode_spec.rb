# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductBarcode, type: :model do
  it 'product barcode should belongs to product' do
    product_barcode = described_class.reflect_on_association(:product)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  it 'product barcode should belongs to order item' do
    product_barcode = described_class.reflect_on_association(:order_item)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  describe ProductBarcode do
    it 'Permit Duplicate Barcodes' do
      described_class.create!(barcode: 'apple-1')
      product_barcode = described_class.new(barcode: 'apple-1', permit_shared_barcodes: true)
      expect(product_barcode).to be_valid
    end
  end

  describe '#create_barcode_from_variant' do
    before do
      Groovepacker::SeedTenant.new.seed
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      @tenant = Tenant.create(name: tenant.to_s)
    end

    after do
      @tenant.destroy
    end
    let(:store) { create(:store, inventory_warehouse_id: InventoryWarehouse.last.id, store_type: 'Shopify') }
    let(:product) { create(:product) }
    let(:variant) { { 'barcode' => '1234567890', 'sku' => 'SKU-123' } }

    it 'creates barcode for product' do
      importer = Groovepacker::Stores::Importers::ShopProductsImporter.new(store)
      importer.send(:create_barcode_from_variant, product, variant)

      expect(product.product_barcodes.count).to eq(1)
      expect(product.product_barcodes.first.barcode).to eq(variant['barcode'])
    end

    context 'when barcode is already created for product' do
      let!(:barcode) { create(:product_barcode, product: product, barcode: '1234567890') }

      it 'does not create duplicate barcode for product' do
        importer = Groovepacker::Stores::Importers::ShopProductsImporter.new(store)
        importer.send(:create_barcode_from_variant, product, variant)

        expect(product.product_barcodes.count).to eq(1)
      end
    end
  end
end
