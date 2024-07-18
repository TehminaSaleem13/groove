# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Oauth::AccessTokensController, type: :controller do
  describe '#session_logging_response' do
    let(:user) { create(:user) }
    let(:token) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: user.id) }
  
    it 'send user session' do
      allow(Groovepacker::LogglyLogger).to receive(:log)
      logs = { user_id: user.id, user_name: user.username }
      post :create, params: { grant_type: 'password', username: user.username, password: user.password }
      expect(Groovepacker::LogglyLogger).to have_received(:log).with(Apartment::Tenant.current, "GPS_user_session", logs)
    end
  end

  describe 'POST #revoke' do
    let(:token) { 'some_token' }

    before do
      allow($redis).to receive(:hdel)
    end

    it 'deletes the token from Redis' do
      post :revoke, params: { token: token }

      expect($redis).to have_received(:hdel).with('groovehacks:session', token)
    end
  end
end
