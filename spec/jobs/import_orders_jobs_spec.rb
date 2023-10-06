require 'rails_helper'

RSpec.describe ImportOrdersJob do

  describe '#perform' do
    let(:store_name) { 'gpmarch' }
    let(:current_tenant) { 'gp55' }
    let(:order_number) { '12345' }
    let(:inventory_warehouse) { create(:inventory_warehouse, is_default: true) }
    let(:store) { create(:store, status: true, store_type: 'Shopify', inventory_warehouse: inventory_warehouse) }
    let(:credential) { create(:shopify_credential, store: store, shop_name: 'gpmarch', access_token: 'shopifytestshopifytestshopifytestshopi', webhook_order_import: true) }
    
    before do
      allow(Apartment::Tenant).to receive(:switch!)
      allow(ShopifyCredential).to receive(:find_by).with(shop_name: store_name).and_return(credential)
    end

    context 'when current_tenant is not blank' do
      before do
        allow(Apartment::Tenant).to receive(:switch!)
      end

      context 'when ShopifyCredential is found' do
        it 'creates an ImportItem and imports the order' do

          importer = described_class.new(store_name, current_tenant, order_number)
          expect(importer.send(:perform,store_name, current_tenant, order_number)).not_to be_nil
        end
      end
    end
  end
end
