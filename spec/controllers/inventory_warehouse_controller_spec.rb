require 'spec_helper'

describe InventoryWarehouseController do

  describe "GET 'create'" do
    it "returns http success" do
      get 'create'
      response.should be_success
    end
  end

  describe "GET 'update'" do
    it "returns http success" do
      get 'update'
      response.should be_success
    end
  end

  describe "GET 'show'" do
    it "returns http success" do
      get 'show'
      response.should be_success
    end
  end

  describe "GET 'index'" do
    it "returns http success" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'destroy'" do
    it "returns http success" do
      get 'destroy'
      response.should be_success
    end
  end

  describe "GET 'adduser'" do
    it "returns http success" do
      get 'adduser'
      response.should be_success
    end
  end

  describe "GET 'removeuser'" do
    it "returns http success" do
      get 'removeuser'
      response.should be_success
    end
  end

end
