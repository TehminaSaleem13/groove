# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true,
                                         add_edit_order_items: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
  end
  
  describe 'Payments' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Get Card And Bank Details' do
      get :index, params: { 'users' => 1, 'amount' => '18576', 'is_annual' => 'false' }
      expect(response.status).to eq(200)
    end

    it 'Create Payment' do
      card_params = { "payment"=>{"last4"=>"4242424242424242", "exp_month"=>"12", "exp_year"=>"2034", "cvc"=>"123", "type"=>"card"} }
      post :create, params: card_params
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
    end
  end
end
