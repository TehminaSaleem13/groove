require 'rails_helper'

describe StoreSettingsController do
  before(:each) do
    SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'amazon_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Amazon Tester', :username=>"amazon_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  describe "POST 'create'" do
    it "creates an amazon store" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :createUpdateStore, { :store_type => 'Amazon', :status => false }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end

  describe "POST 'update'" do
    it "updates an amazon store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'amazon_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh)
      @amazon_credentials = FactoryGirl.create(:amazon_credential, :store_id=>@store.id)
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :createUpdateStore, {:store_type => 'Amazon', :id => @store.id, :status => false }
      
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end
end