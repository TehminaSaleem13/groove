# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroovepackerWebhooksController, type: :controller do
  before do
    user_role = create(:role, name: 'test_user', add_edit_stores: true, import_products: true)
    @user = create(:user, role: user_role)
  end

  describe 'Webhook' do
    let(:token) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    let!(:webhook) { create(:groovepacker_webhook) }  

    before do
      allow(controller).to receive(:doorkeeper_token) { token }
      header = { 'Authorization' => 'Bearer ' + create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'POST #create' do
      it 'Create webhook with all attributes' do
        webhook_params = { webhook: attributes_for(:groovepacker_webhook) }
        expect {
          post :create, params: webhook_params
        }.to change { GroovepackerWebhook.count }.by(1)
        expect(response.status).to eq(201)
      end

      it 'Create webhook without url' do
        webhook_params = { webhook: attributes_for(:groovepacker_webhook).except(:url) }
        post :create, params: webhook_params
        expect(response.status).to eq(422)
        result = JSON.parse(response.body)
        expect(result['errors']['url']).to eq(["can't be blank"])
      end
    end

    context 'PUT #update' do
      it 'Update webhook with all attributes' do
        put :update, params: {id: webhook.id, webhook: { url: 'http://test.groovepacker.com/updated_url', secret_key: 'ggshhsjjs' } }
        expect(response.status).to eq(201)
      end

      it 'Update webhook with nil url' do
        put :update, params: {id: webhook.id, webhook: { url: nil, secret_key: 'ggshhsjjs' } }
        expect(response.status).to eq(422)
        result = JSON.parse(response.body)
        expect(result['errors']['url']).to eq(["can't be blank"])
      end
    end

    context 'DELETE #delete_webhooks' do
      it 'Delete Webhook' do
        expect {
          delete :delete_webhooks, params: {
            webhook_ids: [webhook.id]
          }
        }.to change { GroovepackerWebhook.count }.by(-1)
        expect(response.status).to eq(200)
      end
    end
  end
end
