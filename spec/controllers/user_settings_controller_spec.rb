require 'spec_helper'

describe UserSettingsController do

  describe "GET 'userslist'" do
    it "returns http success" do
      get 'userslist'
      response.should be_success
    end
  end

  describe "GET 'createUser'" do
    it "returns http success" do
      get 'createUser'
      response.should be_success
    end
  end

  describe "GET 'changeuserstatus'" do
    it "returns http success" do
      get 'changeuserstatus'
      response.should be_success
    end
  end

  describe "GET 'edituser'" do
    it "returns http success" do
      get 'edituser'
      response.should be_success
    end
  end

  describe "GET 'duplicateuser'" do
    it "returns http success" do
      get 'duplicateuser'
      response.should be_success
    end
  end

  describe "GET 'deleteuser'" do
    it "returns http success" do
      get 'deleteuser'
      response.should be_success
    end
  end

end
