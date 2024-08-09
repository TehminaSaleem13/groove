require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  describe 'DELETE #delete_customer' do
    it 'returns http success' do
      delete :delete_customer
      expect(response).to have_http_status(:success)
    end
  end

  describe 'DELETE #delete_shop' do
    it 'returns http success' do
      delete :delete_shop
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #show_customer' do
    it 'returns http success' do
      get :show_customer
      expect(response).to have_http_status(:success)
    end
  end

  # describe 'POST #orders_create' do
  #   it 'calls handle_and_enqueue_order_import and returns :ok status' do
  #     expect(controller).to receive(:handle_and_enqueue_order_import)
  #     post :orders_create
  #     expect(response).to have_http_status(:success)
  #   end
  # end

  # describe 'POST #orders_update' do
  #   it 'calls handle_and_enqueue_order_import and returns :ok status' do
  #     expect(controller).to receive(:handle_and_enqueue_order_import)
  #     post :orders_update
  #     expect(response).to have_http_status(:success)
  #   end
  # end

end
