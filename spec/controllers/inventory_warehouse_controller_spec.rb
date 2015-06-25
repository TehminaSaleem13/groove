# require 'spec_helper'
require 'rails_helper'

describe InventoryWarehouseController do
  before(:each) do
    SeedTenant.new.seed
    scanpacksetting = ScanPackSetting.first
    scanpacksetting.ask_tracking_number = true
    scanpacksetting.save

    #@user_role =FactoryGirl.create(:role, :name=>'scan_pack', :import_orders=>true)
    @user = FactoryGirl.create(:user, :username=>"scan_pack_spec_user", :name=>'Scan Pack user', 
      :role => Role.find_by_name('Scan & Pack User'))
    # sign_in @user
    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in :user, @user 
  end
  describe "POST 'create'" do
    it "creates an inventory warehouse" do
      request.accept = "application/json"

      post :create, {:inv_info =>{:name => 'Manhattan Warehouse', :location => 'New Jersey'} }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["success_messages"].length).to eq(1)
      expect(result["success_messages"].length).to eq(1)
      expect(result["success_messages"].first).to eq('Inventory warehouse created successfully')
    end

    it " does not create an inventory warehouse" do
      request.accept = "application/json"

      post :create, { :inv_info => {:location => 'New Jersey'} }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      expect(result["error_messages"].first).to eq('Cannot create warehouse without a name')
    end

    it " does not create an inventory warehouse as the name is not unique" do
      request.accept = "application/json"

      post :create, { :inv_info => { :name => 'Manhattan Warehouse', :location => 'New Jersey' } }
      post :create, { :inv_info => { :name => 'Manhattan Warehouse', :location => 'New York'} }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      expect(result["error_messages"].first).to eq('Name has already been taken')
    end
  end

  describe "PUT 'update'" do
    it "updates the inventory warehouse successfully" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      put :update, { :id => inv_wh.id, :name => 'Manhattan Warehouse1', :location => inv_wh.location }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["success_messages"].length).to eq(1)
      expect(result["success_messages"].first).to eq('Inventory warehouse updated successfully')

      inv_wh.reload
      expect(inv_wh.name).to eq('Manhattan Warehouse1')
    end

    it "does not updates the inventory warehouse because it does not exist" do
      request.accept = "application/json"

      put :update, { :id => 1, :name => 'Manhattan Warehouse', :location => 'New Jersey'}

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      expect(result["error_messages"].first).to eq('Couldn\'t find InventoryWarehouse with id=1')
    end

    it "does not update the inventory warehouse because the name already exists" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'Manhattan Warehouse')
      inv_wh2 = FactoryGirl.create(:inventory_warehouse, :name=>'Manhattan Warehouse1')
      
      put :update, { :id => inv_wh2.id, :name => 'Manhattan Warehouse', :location => 'New Jersey'}

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      expect(result["error_messages"].first).to eq('Name has already been taken')
    end
  end

  describe "GET inventory warehouse" do
    it "returns detail of inventory warehouse" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'Manhattan Warehouse')
      inv_wh2 = FactoryGirl.create(:inventory_warehouse, :name=>'Manhattan Warehouse1')
      
      get :show, { :id => inv_wh2.id}

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["inv_wh_info"]["name"]).to eq('Manhattan Warehouse1')
      #expect(result["data"]["inv_wh_users"]).to eq([])

      get :show, { :id => inv_wh.id}

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["inv_wh_info"]["name"]).to eq('Manhattan Warehouse')
      #expect(result["data"]["inv_wh_users"]).to eq([])
    end
  end

  describe "GET 'index'" do
    it "returns http success" do
      # get 'index'
      # response.should be_success
    end
  end

  describe "GET 'destroy'" do
    it "returns http success" do
      # get 'destroy'
      # response.should be_success
    end
  end

  describe "GET 'adduser'" do
    it "returns http success" do
      # get 'adduser'
      # response.should be_success
    end
  end

  describe "GET 'removeuser'" do
    it "returns http success" do
      # get 'removeuser'
      # response.should be_success
    end
  end

end
