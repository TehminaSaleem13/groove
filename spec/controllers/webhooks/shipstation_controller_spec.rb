require 'rails_helper'

RSpec.describe Webhooks::ShipstationController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
  end

  describe 'Shipstation API 2 Imports' do
    let(:store) { FactoryBot.create(:store, store_type: 'Shipstation API 2', name: 'Shipstation API 2', inventory_warehouse: @inv_wh, status: true) }
    let!(:ss_credential) { FactoryBot.create(:shipstation_rest_credential, store: store) }
    let!(:resource_url) { "https://ssapi.shipstation.com/orders?importBatch=567e0222-jdjd-2a3e-3357-c20af230e2bc" }

    it 'imports order via webhook' do
      allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Service).to receive(:query).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_single_order.yaml'))))

      get :import, params: { resource_url: resource_url, credential_id:  ss_credential.id}
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)
    end
  end
end
