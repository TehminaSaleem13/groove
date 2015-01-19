require 'rails_helper'

describe OrdersController do
  before(:each) do
    SeedTenant.new.seed

    @user_role = FactoryGirl.create(:role,:name=>'order_import_spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Order Import Tester', :username=>"order_import_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @access_restriction.inspect
  end

  it "imports orders for amazon store" do
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'amazon_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
    @amazon_credentials = FactoryGirl.create(:amazon_credential, :store_id=>@store.id)
    request.accept = "application/json"
    post :importorders, {:id => @store.id}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    puts result.inspect
    expect(result['status']).to eq(true)
    expect(result['messages']).to eq([])
  end
  # it "imports orders for ebay store" do
  #   @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'ebay_inventory_warehouse')
  #   @store = FactoryGirl.create(:store, :name=>'ebay_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Ebay')
  #   @ebay_credentials = FactoryGirl.create(:ebay_credential, :store_id=>@store.id)
  #   request.accept = "application/json"
  #   post :importorders, {:id => @store.id}
  #   expect(response.status).to eq(200)
  #   result = JSON.parse(response.body)
  #   puts result.inspect
  #   expect(result['status']).to eq(true)
  #   expect(result['messages']).to eq([])
  # end
  it "imports orders for magento store" do
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'magento_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'magento_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Magento')
    @magento_credentials = FactoryGirl.create(:magento_credential, :store_id=>@store.id)
    request.accept = "application/json"
    post :importorders, {:id => @store.id}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    puts result.inspect
    expect(result['status']).to eq(true)
    expect(result['messages']).to eq([])
  end
  # it "imports orders for shipstation store" do
  #   @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipstation_inventory_warehouse')
  #   @store = FactoryGirl.create(:store, :name=>'shipstation_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Shipstation')
  #   @shipstation_credentials = FactoryGirl.create(:shipstation_credential, :store_id=>@store.id)
  #   request.accept = "application/json"
  #   post :importorders, {:id => @store.id}
  #   expect(response.status).to eq(200)
  #   result = JSON.parse(response.body)
  #   puts result.inspect
  #   expect(result['status']).to eq(true)
  #   expect(result['messages']).to eq([])
  # end
  it "imports orders for shipstation API 2 store" do
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipstation_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'shipstation_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Shipstation API 2')
    @shipstation_rest_credentials = FactoryGirl.create(:shipstation_rest_credential, :store_id=>@store.id)
    request.accept = "application/json"
    post :importorders, {:id => @store.id}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['status']).to eq(true)
    expect(result['messages']).to eq([])
    puts result.inspect
  end
  # it "imports orders for shipworks store" do
  #   @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipworks_inventory_warehouse')
  #   @store = FactoryGirl.create(:store, :name=>'shipworks_store', :inventory_warehouse=>@inv_wh, :status => true)
  #   @shipworks_credentials = FactoryGirl.create(:shipworks_credential, :store_id=>@store.id)
  #   request.accept = "application/json"
  #   request.headers["HTTP_USER_AGENT"].clear
  #   request.headers["HTTP_USER_AGENT"] << 'shipworks'
  #   post :import_shipworks, {:auth_token => @shipworks_credentials.auth_token}
  #   expect(response.status).to eq(200)
  #   result = JSON.parse(response.body)
  #   puts result.inspect
  # end
end