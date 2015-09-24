require 'rails_helper'

describe StoresController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'shipstation_rest_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Shipstation Rest Tester', :username=>"shipstation_rest_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  describe "POST 'create'" do
    it "creates an shipstation API 2 store" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'Shipstation API 2', :status => false }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end

  describe "POST 'update'" do
    it "updates an shipstation API 2 store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipstation_rest_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'shipstation_rest_store', :inventory_warehouse=>@inv_wh)
      @shipstation_rest_credentials = FactoryGirl.create(:shipstation_rest_credential, :store_id=>@store.id)
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'Shipstation API 2', :id => @store.id, :status => false }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end
end