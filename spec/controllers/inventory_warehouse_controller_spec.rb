require 'spec_helper'

describe InventoryWarehouseController do

  describe "POST 'create'" do
    it "creates an inventory warehouse" do
      request.accept = "application/json"

      post :create, { :name => 'Manhattan Warehouse', :location => 'New Jersey' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["success_messages"].length).to eq(1)
      expect(result["success_messages"].length).to eq(1)
      expect(result["success_messages"].first).to eq('Inventory warehouse created successfully')
    end

    it " does not create an inventory warehouse" do
      request.accept = "application/json"

      post :create, { :location => 'New Jersey' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      expect(result["error_messages"].first).to eq('Cannot create warehouse without a name')
    end

    it " does not create an inventory warehouse as the name is not unique" do
      request.accept = "application/json"

      post :create, { :name => 'Manhattan Warehouse', :location => 'New Jersey' }
      post :create, { :name => 'Manhattan Warehouse', :location => 'New York' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      puts result['error_messages']
      expect(result["error_messages"].first).to eq('Name has already been taken')
    end
  end

  describe "GET 'update'" do
    it "returns http success" do
      request.accept = "application/json"

      post :create, { :name => 'Manhattan Warehouse', :location => 'New Jersey' }
      post :create, { :name => 'Manhattan Warehouse', :location => 'New York' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"].length).to eq(1)
      puts result['error_messages']
      expect(result["error_messages"].first).to eq('Name has already been taken')
    end
  end

  describe "GET 'show'" do
    it "returns http success" do
      # get 'show'
      # response.should be_success
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
