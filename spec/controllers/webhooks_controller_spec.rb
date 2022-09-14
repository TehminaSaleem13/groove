# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  context 'POST #delete_customer' do
    it 'returns 200' do
      post :delete_customer
      expect(response.status).to eq 200
    end
  end

  context 'POST #delete_shop' do
    it 'returns 200' do
      post :delete_shop
      expect(response.status).to eq 200
    end
  end

  context 'POST #show_customer' do
    it 'returns 200' do
      post :show_customer
      expect(response.status).to eq 200
    end
  end
end
