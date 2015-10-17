require 'rails_helper'

RSpec.describe SubscriptionsController, :type => :controller do
  before(:each) do
    FactoryGirl.create(:tenant, :name=>"sitetest")
    FactoryGirl.create(:subscription, :email=>"test_user@gmail.com")
    #@s_token = Stripe::Token.create( :card => { :number => "4111111111111111", :exp_month => 10, :exp_year => 2018, :cvc => "121" })
  end
  after(:each) do
    Delayed::Job.destroy_all
  end
  
  describe "Spec for User subscriptions" do
    it "Tenant name should be invalidate" do
      request.accept = "application/json"
      get :valid_tenant_name, {"tenant_name"=>"sitetest", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['valid']).to eq(false)
    end

    it "Tenant name should be validate" do
      request.accept = "application/json"
      get :valid_tenant_name, {"tenant_name"=>"sitetest1", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['valid']).to eq(true)
    end

    it "Email for subscription should be invalidate" do
      request.accept = "application/json"
      get :valid_email, {"email"=>"test_user@gmail.com", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['valid']).to eq(false)
    end

    it "Email for subscription should be validate" do
      request.accept = "application/json"
      get :valid_email, {"email"=>"test_use1r@gmail.com", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['valid']).to eq(true)
    end

    it "Promotion code should be invalid" do
      request.accept = "application/json"
      get :validate_coupon_id, {"coupon_id"=>"TestCoupon50", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
    end

    it "Promotion code should be valid" do
      request.accept = "application/json"
      get :validate_coupon_id, {"coupon_id"=>"COUGROOVE50", "subscription"=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end

    it "Should invalidate stripe token for user subscription" do
      request.accept = "application/json"
      doc = IO.read(Rails.root.join("spec/fixtures/files/subscription_data"))
      subscription_data = eval(doc)
      #subscription_data["stripe_user_token"] = @s_token.id
      #subscription_data["subscription"]["stripe_user_token"] = @s_token.id
      post :confirm_payment, subscription_data
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['valid']).to eq(false)
    end

  end
end