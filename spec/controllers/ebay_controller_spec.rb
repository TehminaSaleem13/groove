require 'rails_helper'

describe StoreSettingsController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'ebay_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Ebay Tester', :username=>"ebay_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  describe "POST 'create'" do
    it "creates an ebay store" do      
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'Ebay', :status => false }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end

  describe "POST 'update'" do
    it "updates an ebay store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'ebay_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'ebay_store', :inventory_warehouse=>@inv_wh)
      @ebay_credentials = FactoryGirl.create(:ebay_credential, :store_id=>@store.id)
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'Ebay', :id => @store.id, :status => false }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end
end