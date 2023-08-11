# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OriginStoresController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    inv_wh = FactoryBot.create(:inventory_warehouse, is_default: true)
    @store = FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id)
    @user = FactoryBot.create(:user, username: 'scan_pack_spec_user', name: 'Scan Pack user', role: Role.find_by_name('Scan & Pack User'))
  end

  describe 'PATCH #update' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    let(:origin_store) { create(:origin_store, store: @store) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'with valid parameters' do
      it "updates the origin store's store name" do
        patch :update, params: { origin_store_id: origin_store.origin_store_id, origin_store: { store_name: 'New Store Name' } }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['store_name']).to eq('New Store Name')
      end
    end

    context 'with invalid parameters' do
      it 'returns error messages' do
        patch :update, params: { origin_store_id: origin_store.origin_store_id, origin_store: { store_name: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).not_to be_empty
      end
    end

    context 'when origin store is not found' do
      it 'returns a not found error' do
        patch :update, params: { origin_store_id: 'non_existent_id', origin_store: { store_name: 'New Store Name' } }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Origin Store not found')
      end
    end
  end
end
