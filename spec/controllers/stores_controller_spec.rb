require 'rails_helper'

describe StoresController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'stores_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Store Tester', :username=>"store_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  describe "POST 'create'" do
    it "creates an BigCommerce store" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { 
        :store_type => 'BigCommerce', 
        :status => false,
        :api_key => "HELLO",
        :api_secret => "SECRET",
        :regular_import_range => 3 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['store_id']).to be_present
      store = Store.find_by_id(result['store_id'])
      expect(store.status).to eq(false)
      expect(store.store_type).to eq("BigCommerce")
      expect(store.big_commerce_credential).to be_present
    end
  end

  describe "POST 'update'" do
    it "updates an BigCommerce store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'big_commerce_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'big_commerce_store', :inventory_warehouse=>@inv_wh, :status => false)
      @big_commerce_credential = FactoryGirl.create(:big_commerce_credential, :store_id=>@store.id)
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'BigCommerce', :id => @store.id, :status => true }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['store_id']).to be_present
      store = Store.find_by_id(result['store_id'])
      expect(store.status).to eq(true)
      expect(store.store_type).to eq("BigCommerce")
      expect(store.big_commerce_credential).to be_present
    end
  end
  
  describe "POST 'create'" do
    it "creates an ShippingEasy store" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { 
        :store_type => 'ShippingEasy', 
        :status => false,
        :api_key => "HELLO",
        :api_secret => "SECRET",
        :import_ready_for_shipment => true,
        :import_shipped => true,
        :gen_barcode_from_sku => true
      }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['store_id']).to be_present
      store = Store.find_by_id(result['store_id'])
      expect(store.status).to eq(false)
      expect(store.store_type).to eq("ShippingEasy")
      expect(store.shipping_easy_credential).to be_present
    end
  end

  describe "POST 'update'" do
    it "updates an ShippingEasy store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipping_easy_inventory_warehouse')
      @store = FactoryGirl.create(:store, :name=>'shipping_easy_store', :inventory_warehouse=>@inv_wh, :status => false)
      @big_commerce_credential = FactoryGirl.create(:shipping_easy_credential, :store_id=>@store.id, :api_key=>'xxxxxxxxxxxxxxxx', :api_secret=>'yyyyyyyyyyyyyyyyyyyyyyyyyyy', :import_ready_for_shipment => true, :import_shipped => true, :gen_barcode_from_sku => true)
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_stores, true)
      post :create_update_store, { :store_type => 'ShippingEasy', :id => @store.id, :status => true }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['store_id']).to be_present
      store = Store.find_by_id(result['store_id'])
      expect(store.status).to eq(true)
      expect(store.store_type).to eq("ShippingEasy")
      expect(store.shipping_easy_credential).to be_present
    end
  end
  
  # describe "GET 'getactivestores'" do
  #   it "Should not return any active stores" do
  #     @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'big_commerce_inventory_warehouse1')
  #     @store = FactoryGirl.create(:store, :name=>'big_commerce_store1', :inventory_warehouse=>@inv_wh)
  #     @big_commerce_credential = FactoryGirl.create(:big_commerce_credential, :store_id=>@store.id)
  #     request.accept = "application/json"
  #     get :getactivestores, {}
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result['status']).to eq(true)
  #     expect(result['stores']).to be_blank
  #   end
    
  #   it "Should return all active stores" do
  #     @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'big_commerce_inventory_warehouse2')
  #     @store = FactoryGirl.create(:store, :name=>'big_commerce_store2', :store_type => 'BigCommerce', :inventory_warehouse=>@inv_wh, :status => true)
  #     @big_commerce_credential = FactoryGirl.create(:big_commerce_credential, :store_id=>@store.id)
      
  #     @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'amazon_inventory_warehouse')
  #     @store = FactoryGirl.create(:store, :name=>'amazon_store', :store_type => 'Amazon', :inventory_warehouse=>@inv_wh, :status => true)
  #     @amazon_credentials = FactoryGirl.create(:amazon_credential, :store_id=>@store.id)
  #     request.accept = "application/json"
  #     post :getactivestores, {}
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result['status']).to eq(true)
  #     expect(result['stores'].length).to eq(2)
  #   end
  # end
  
  describe "POST 'create_update_ftp_credentials'" do
    it "Should not create or update ftp credentials for CSV type store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_store_inv_warehouse')
      @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type => 'CSV', :inventory_warehouse=>@inv_wh)
      #@big_commerce_credential = FactoryGirl.create(:big_commerce_credential, :store_id=>@store.id)
      request.accept = "application/json"
      post :create_update_ftp_credentials, {:id => "", :username => "TEST", :password => "TEST"}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      @ftp_credential = @store.ftp_credential
      expect(@ftp_credential).to be_nil
    end
    
    it "Should create or update ftp credentials for CSV type store" do
      @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_store_inv_warehouse')
      @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type => 'CSV', :inventory_warehouse=>@inv_wh)
      request.accept = "application/json"
      post :create_update_ftp_credentials, {:id => @store.id, :username => "TEST", :password => "TEST"}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      @ftp_credential = @store.ftp_credential
      expect(@ftp_credential.password).to eq("TEST")
      expect(@ftp_credential.username).to eq("TEST")
    end
  end
end
