require 'spec_helper'

describe StoreSettingsController do

  describe "GET 'createStore'" do
    it "returns http success" do
      get 'createStore'
      response.should be_success
    end
  end

  describe "GET 'changestorestatus'" do
    it "returns http success" do
      get 'changestorestatus'
      response.should be_success
    end
  end

  describe "GET 'editstore'" do
    it "returns http success" do
      get 'editstore'
      response.should be_success
    end
  end

  describe "GET 'duplicatestore'" do
    it "returns http success" do
      get 'duplicatestore'
      response.should be_success
    end
  end

  describe "GET 'deletestore'" do
    it "returns http success" do
      get 'deletestore'
      response.should be_success
    end
  end

end
