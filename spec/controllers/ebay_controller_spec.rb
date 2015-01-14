require 'rails_helper'

describe StoreSettingsController do
  before(:each) do
    SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'ebay_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Ebay Tester', :username=>"ebay_spec_tester", :role => @user_role)
    sign_in @user
  end

  describe "POST 'create'" do
    it "creates an ebay store" do
      @access_restriction = FactoryGirl.create(:access_restriction)
      @access_restriction.inspect
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'ebay_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'ebay_store', :inventory_warehouse=>@inv_wh)

      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :createUpdateStore, { :store_type => 'Ebay' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end
end