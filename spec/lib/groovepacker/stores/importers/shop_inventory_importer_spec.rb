# frozen_string_literal: true

require 'rails_helper'

describe Groovepacker::Stores::Importers::ShopInventoryImporter do
  subject { described_class.new(tenant_name, shopify_store.id) }

  let(:tenant) { create(:tenant, name: Apartment::Tenant.current) }
  let(:tenant_name) { tenant.name }
  let(:shopify_store) { create(:store, :shopify) }

  let(:inv_level1) { { id: 123, inventory_item_id: 123, available: 2 }.with_indifferent_access }
  let(:inv_level2) { { id: 456, inventory_item_id: 456, available: 1 }.with_indifferent_access }
  let(:inventory_levels) { [inv_level1, inv_level2] }

  before do
    subject.send :init_credential_and_client
  end

  describe 'instance variables' do
    it 'has tenant and store_id' do
      expect(subject.tenant).to eq(tenant_name)
      expect(subject.store_id).to eq(shopify_store.id)
    end
  end

  describe 'methods' do
    describe '#pull_inventories' do
      let(:shopify_product_variant_id) { inv_level2[:id] }
      let(:current_inv_qty) { 10 }
      let(:new_inv_qty) { inv_level2[:available] }
      let(:inv_qty_difference) { new_inv_qty - current_inv_qty }
      let(:variant) do
        {
          id: inv_level2[:id],
          product_id: inv_level2[:id],
          title: 'Default Title',
          inventory_item_id: inv_level2[:id],
          inventory_quantity: current_inv_qty
        }.with_indifferent_access
      end
      let(:product) { create(:product, :with_sku_barcode) }

      before do
        create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: shopify_product_variant_id)
        product.primary_warehouse.update(available_inv: current_inv_qty)
        allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:inventory_levels).and_return(inventory_levels)
        allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:get_variant).and_return(variant)
      end

      it 'performs the inventory import from shopify' do
        expect { subject.pull_inventories }.to change { product.reload.primary_warehouse.quantity_on_hand }.by(inv_qty_difference)
      end
    end
  end

  describe 'private methods' do
    describe '#send_pull_inventories_products_email' do
      let(:csv_export_mailer) { double('CsvExportMailer', deliver: true) }

      before do
        allow(CsvExportMailer).to receive(:send_push_pull_inventories_products).and_return(csv_export_mailer)
        subject.send :send_pull_inventories_products_email
      end

      it 'triggers an email' do
        expect(CsvExportMailer).to have_received(:send_push_pull_inventories_products)
      end
    end

    describe '#inventory_levels' do
      before do
        allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:inventory_levels).and_return(inventory_levels)
      end

      it 'returns inventory levels' do
        expect(subject.send(:shopify_inventory_levels)).to match_array(inventory_levels)
      end
    end

    describe '#get_inventory' do
      let(:shopify_product_variant_id) { inv_level2[:id] }
      let(:variant) do
        {
          id: inv_level2[:id],
          product_id: inv_level2[:id],
          title: 'Default Title',
          inventory_item_id: inv_level2[:id],
          inventory_quantity: 10
        }.with_indifferent_access
      end

      let(:updated_variant) do
        variant.merge(inventory_quantity: inv_level2[:available])
      end

      before do
        allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:inventory_levels).and_return(inventory_levels)
        allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:get_variant).and_return(variant.dup)
      end

      it 'returns inventory levels' do
        expect(subject.send(:get_inventory, shopify_product_variant_id)).to eq(updated_variant)
      end
    end
  end
end
