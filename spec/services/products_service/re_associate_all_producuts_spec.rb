require 'rails_helper'

RSpec.describe ProductsService::ReAssociateAllProducts do
  describe '#call' do
    let(:tenant) { 'example_tenant' }
    let(:inventory_warehouse) { create(:inventory_warehouse, is_default: true) }
    let(:store) { create(:store, status: true, store_type: 'Shopify', inventory_warehouse:) }
    let(:params) { { tenant:, store_id: store.id } }
    let(:service) { described_class.new(tenant:, params:) }

    before do
      Groovepacker::SeedTenant.new.seed
      allow(Apartment::Tenant).to receive(:switch!).and_return(true)
      allow(Groovepacker::ShopifyRuby::Client).to receive_message_chain(:new,
                                                                        :products).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_products.yaml'))))
      product = create(:product, :with_sku_barcode, store:, store_product_id: nil)
      create(:product_sku, product:, sku: 'TOY97')
    end

    context 'when shopify_credential is present' do
      before do
        create(:shopify_credential, store:, shop_name: 'shopify_test',
                                    access_token: 'shopifytestshopifytestshopifytestshopi')
      end

      it 'calls update_re_associate_shopify_products' do
        allow(service).to receive(:update_re_associate_shopify_products)
        service.call
        expect(service).to have_received(:update_re_associate_shopify_products)
      end

      it 'calls send_re_associate_all_products_email' do
        allow(service).to receive(:send_re_associate_all_products_email)
        service.call
        expect(service).to have_received(:send_re_associate_all_products_email)
      end
    end

    context 'when shopify_credential is nil' do
      it 'does not call update_re_associate_shopify_products' do
        allow(service).to receive(:update_re_associate_shopify_products)
        service.call
        expect(service).not_to have_received(:update_re_associate_shopify_products)
      end

      it 'does not call send_re_associate_all_products_email' do
        allow(service).to receive(:send_re_associate_all_products_email)
        service.call
        expect(service).not_to have_received(:send_re_associate_all_products_email)
      end
    end
  end
end
