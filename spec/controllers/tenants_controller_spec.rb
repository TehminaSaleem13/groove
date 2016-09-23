require 'rails_helper'

RSpec.describe TenantsController, :type => :controller do
  before(:each) do
  	FactoryGirl.create(:tenant, :name=>"myplan")
  end

  it "orders delete days with basicinfo present " do
		request.accept = "application/json"
		doc = IO.read(Rails.root.join("spec/fixtures/files/access_restriction"))
		access_restriction_data = eval(doc)
		FactoryGirl.create(:subscription, :email=>"success@simulator.amazonses.com", :tenant_id=>Tenant.last.id, :stripe_customer_id=>access_restriction_data["subscription_info"]["customer_id"], :subscription_plan_id=>access_restriction_data["subscription_info"]["plan_id"], :customer_subscription_id=>access_restriction_data["subscription_info"]["customer_subscription_id"], :stripe_transaction_identifier => "txn_18ORMF44KQj1OQ8CCFShAV35", :stripe_user_token => "tok_18ORM844KQj1OQ8CIvrT4Z5d")
		customer_subscription = Stripe::Customer.retrieve(access_restriction_data["subscription_info"]["customer_id"]).subscriptions
		access_restriction_data["subscription_info"]["plan_id"] = customer_subscription["data"][0].plan.id
		access_restriction_data["id"] = Tenant.last.id
		post :update_access_restrictions, access_restriction_data
		expect(response.status).to eq(200)
		result = JSON.parse(response.body)
  end

  it "orders delete days with basicinfo absent" do
		request.accept = "application/json"
		doc = IO.read(Rails.root.join("spec/fixtures/files/access_restriction"))
		access_restriction_data = eval(doc)
		access_restriction_data["basicinfo"] = {}
		access_restriction_data["id"] = Tenant.last.id
		FactoryGirl.create(:subscription, :email=>"success@simulator.amazonses.com", :tenant_id=>Tenant.last.id, :stripe_customer_id=>access_restriction_data["subscription_info"]["customer_id"], :subscription_plan_id=>access_restriction_data["subscription_info"]["plan_id"], :customer_subscription_id=>access_restriction_data["subscription_info"]["customer_subscription_id"], :stripe_transaction_identifier => "txn_18ORMF44KQj1OQ8CCFShAV35", :stripe_user_token => "tok_18ORM844KQj1OQ8CIvrT4Z5d")
		customer_subscription = Stripe::Customer.retrieve(access_restriction_data["subscription_info"]["customer_id"]).subscriptions
		access_restriction_data["subscription_info"]["plan_id"] = customer_subscription["data"][0].plan.id
		post :update_access_restrictions, access_restriction_data
		expect(response.status).to eq(200)
		result = JSON.parse(response.body)
  end
end