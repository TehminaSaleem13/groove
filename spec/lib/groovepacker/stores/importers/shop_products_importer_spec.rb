require 'rails_helper'

RSpec.describe Groovepacker::Stores::Importers::ShopProductsImporter do
  before do
    Groovepacker::SeedTenant.new.seed
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
  end

  after do
    @tenant.destroy
  end

  context 'private' do
    let(:store) { create(:store, inventory_warehouse_id: InventoryWarehouse.last.id, store_type: 'Shopify') }

    describe '#initialize_import_objects' do
      it 'initializes the import objects correctly' do
        importer = described_class.new(store)
        expect(importer.send(:initialize_import_objects)).to be_nil
      end
    end

    describe '#custom_shop_item?' do
      it 'returns true if item is a custom shopify item' do
        importer = described_class.new(store)
        item = {
          'fulfillable_quantity' => 1,
          'gift_card' => false,
          'product_id' => nil,
          'sku' => nil,
          'product_exists' => false,
          'variant_id' => nil
        }
        expect(importer.send(:custom_shop_item?, item)).to be_truthy
      end

      it 'returns false if item is not a custom shopify item' do
        importer = described_class.new(store)
        item = {
          'fulfillable_quantity' => nil,
          'gift_card' => false,
          'product_id' => 123,
          'sku' => 'ABCD1234',
          'product_exists' => true,
          'variant_id' => 456
        }
        expect(importer.send(:custom_shop_item?, item)).to be_falsey
      end
    end

    describe '#assign_attr_to_variant_for_custom_item' do
      let(:vari) { { 'sku' => '', 'barcode' => '', 'grams' => 500, 'quantity' => 10 } }
      let(:item) { { 'id' => 123  } }

      it 'assigns attributes to variant for custom item' do
        importer = described_class.new(store)
        variant = importer.send(:assign_attr_to_variant_for_custom_item, vari, item)
        expect(variant['sku']).to eq('C-123')
        expect(variant['barcode']).to eq('C-123')
        expect(variant['weight']).to eq(500)
        expect(variant['inventory_quantity']).to eq(10)
      end

      it 'does not assign attributes to variant for non-custom item' do
        importer = described_class.new(store)
        non_custom_item = { 'id' => '' }
        variant = importer.send(:assign_attr_to_variant_for_custom_item, vari, non_custom_item) if !importer.send(:custom_shop_item?, item)
        expect(variant['sku']).to eq('C-')
        expect(variant['barcode']).to eq('C-')
        expect(variant['weight']).to eq(500)
        expect(variant['inventory_quantity']).to eq(10)
      end
    end
  end
end
