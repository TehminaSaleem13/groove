# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopifyController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
  end

  describe 'Shopify Store' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    # Not needed now
    # it 'Get Auth' do
    #   request.accept = 'application/json'
    #   post :get_auth, params: { shop_name: 'test_shop' }
    #   expect(response.status).to eq(200)
    # end
  end
end
