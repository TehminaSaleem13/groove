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
end
