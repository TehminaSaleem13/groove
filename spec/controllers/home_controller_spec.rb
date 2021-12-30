# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
  end

  describe 'Import Status' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Get Import Status' do
      request.accept = 'application/json'
      get :import_status
      expect(response.status).to eq(200)
    end
  end
end
