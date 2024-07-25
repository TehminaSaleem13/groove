# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderTagsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    inv_wh = FactoryBot.create(:inventory_warehouse, is_default: true)
    @store = FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id)
    @user = FactoryBot.create(:user, username: 'scan_pack_spec_user', name: 'Scan Pack user', role: Role.find_by_name('Scan & Pack User'))
  end

  let!(:order_tag1) { OrderTag.create(name: 'Tag1') }
  let!(:order_tag2) { OrderTag.create(name: 'Tag2') }
  let!(:duplicate_tag) { OrderTag.create(name: 'Tag1') }
  let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
  let(:origin_store) { create(:origin_store, store: @store) }

  describe 'GET #index' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'returns a unique list of order tags' do
      get :index
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response.map { |tag| tag['name'] }).to include('Tag1', 'Tag2')
    end
  end

  describe 'GET #search' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end
  
    context 'when name parameter is present' do
      it 'returns a list of order tags matching the search term' do
        get :search, params: { name: 'Tag1' }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.count).to eq(1)
        expect(json_response.first['name']).to eq('Tag1')
      end

      it 'returns a unique list of order tags matching the search term' do
        get :search, params: { name: 'Tag' }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.count).to eq(2)
        expect(json_response.map { |tag| tag['name'] }).to include('Tag1', 'Tag2')
      end
    end

    context 'when name parameter is not present' do
      it 'returns an error' do
        get :search
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Name parameter is required')
      end
    end
  end

  describe 'POST #create_or_update' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'when creating a new order tag' do
      it 'creates a new order tag and returns it' do
        post :create_or_update, params: { order_id: { name: 'NewTag', color: 'Blue' } }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('NewTag')
        expect(json_response['color']).to eq('Blue')
      end
    end

    context 'when updating an existing order tag' do
      it 'updates the order tag and returns it' do
        post :create_or_update, params: { order_id: { id: order_tag1.id, name: 'UpdatedTag', color: 'Red' } }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('UpdatedTag')
        expect(json_response['color']).to eq('Red')
      end
    end
  end

  describe 'PUT #update' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'when updating an existing order tag' do
      it 'updates the order tag and returns it' do
        put :update, params: { id: order_tag1.id, order_id: { name: 'UpdatedTag', color: 'Red' } }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('UpdatedTag')
        expect(json_response['color']).to eq('Red')
      end
    end
  end
end
