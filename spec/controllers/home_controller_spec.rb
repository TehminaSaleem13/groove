# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  before do
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

    it 'Get User info' do
      request.accept = 'application/json'
      get :userinfo
      expect(response.status).to eq(200)
    end

    it 'Get User info with confirmation code and barcode' do
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product, barcode: 'testPRODUCT1')
      ScanPackSetting.last.update(require_serial_lot: true, valid_prefixes: 'test')
      request.accept = 'application/json'
      get :userinfo
      expect(response.status).to eq(200)
    end
  end
end
