# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Internal::HealthCheckController, type: :controller do
  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
      expect(response.body).to eq('OK')
    end
  end
end
