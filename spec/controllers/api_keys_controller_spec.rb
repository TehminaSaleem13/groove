# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiKeysController, type: :controller do
  let(:user) { FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester') }
  let(:token) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: user.id) }
  let(:api_key) { FactoryBot.create(:api_key) }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
    header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: user.id).token }
    request.headers.merge! header
  end

  describe 'POST #create' do
    before do
      post :create
    end

    it 'returns a successful response' do
      expect(response).to have_http_status(:created)
    end

    it 'creates a new API key' do
      expect(ApiKey.where(author: user).count).to eq(1)
    end

    it 'returns success message in JSON response' do
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to be_truthy
      expect(json_response['success_messages']).to include('Api Key generated')
    end
  end

  describe 'DELETE #destroy' do
    before do
      delete :destroy, params: { id: api_key.id }
    end

    context 'when API key is found' do
      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'marks the API key as deleted' do
        api_key.reload
        expect(api_key.deleted_at).to be_present
      end

      it 'returns success message in JSON response' do
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to be_truthy
        expect(json_response['success_messages']).to include('Api Key deleted')
      end
    end

    context 'when API key is not found' do
      before do
        delete :destroy, params: { id: 999 }
      end

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message in JSON response' do
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to be_falsey
        expect(json_response['error_messages']).to include('Api Key not found')
      end
    end
  end
end
