require 'spec_helper'

describe ScanPackController do

	before(:each) do 
	  @user = FactoryGirl.create(:user)
	  sign_in @user
	  @user.add_role :project_manager
	end

  describe "Order Scan" do

   	it "should not scan orders with no barcode" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order)

      get :scan_order_by_barcode

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Please specify a barcode to scan the order")
    end
  
   	it "should process order scan for orders having a status of Awaiting Scanning" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order)

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("Awaiting Scanning")
      expect(result["data"]["next_state"]).to eq("ready_for_product")
    end

   	it "should process order scan for orders having a status of Scanned" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'Scanned', :scanned_on=> "2013-09-03")

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("Scanned")
      expect(result["data"]["next_state"]).to eq("ready_for_order")
      expect(result["data"]["scanned_on"]).to eq("2013-09-03")
      expect(result["notice_messages"][0]).to eq("This order has already been scanned")
    end

   	it "should process order scan for orders having a status of Cancelled" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'Cancelled')

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("Cancelled")
      expect(result["data"]["next_state"]).to eq("ready_for_order")
      expect(result["notice_messages"][0]).to eq("This order has been cancelled")
    end


   end
end
