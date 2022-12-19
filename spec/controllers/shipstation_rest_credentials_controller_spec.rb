# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShipstationRestCredentialsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'shipstation_API', store_type: 'Shipstation API 2', inventory_warehouse: @inv_wh, status: true)
    @shipstation = FactoryBot.create(:shipstation_rest_credential, store_id: @store.id)
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
  end

  describe 'Update API' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'set contracted carriers API' do
      post :set_contracted_carriers, params: { credential_id: @shipstation.id, carrier_code: 'Stamps_com' }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)

      post :set_contracted_carriers, params: { credential_id: @shipstation.id, carrier_code: 'Stamps_com' }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end

    it 'set presets API' do
      post :set_presets, params: { credential_id: @shipstation.id, presets: { "presets1": '20x20x20(centimeters)' } }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
    end
  end
end
