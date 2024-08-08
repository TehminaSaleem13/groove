require 'rails_helper'

RSpec.describe ImportOrdersJob do

  # describe '#perform' do
  #   let(:tenant) { create(:tenant, name: Apartment::Tenant.current) }
  #   let(:tenant_name) { tenant.name }
  #   let(:shopify_store) { create(:store, :shopify) }
  #   let(:order_number) { '12345' }
  #   let(:context) { instance_double('Groovepacker::Stores::Context') }
  #   let(:shopify_credential) { shopify_store.shopify_credential }

  #   before do
  #     allow(Groovepacker::Stores::Context).to receive(:new).and_return(context)
  #     shopify_credential.update(webhook_order_import: true)
  #     allow(context).to receive(:import_single_order_from)
  #   end

  #   context 'when order should be imported' do
  #     it 'initiates the import' do
  #       described_class.new.perform(shopify_credential.shop_name, tenant_name, order_number)
  #       expect(context).to have_received(:import_single_order_from).with(order_number)
  #     end
  #   end
  # end
end
