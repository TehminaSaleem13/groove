require 'rails_helper'

RSpec.describe ShipstationRestCredentialsController, :type => :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @user_role = FactoryGirl.create(:role,:name=>'shipstation_rest_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Shipstation Rest Tester', :username=>"shipstation_rest_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  describe "PUT 'fix_import_dates'" do 
    it "fix date 24 hours" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipstation_rest_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'shipstation_rest_store', :inventory_warehouse=>@inv_wh)
      @shipstation_rest_credentials = FactoryGirl.create(:shipstation_rest_credential, :store_id=>@store.id)
      request.accept = "application/json"
      response = put :fix_import_dates, {:store_id => @store.id, :shipstation_rest_credential => {}} 
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
    end
  end
end
