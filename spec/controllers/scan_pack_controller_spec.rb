require 'spec_helper'

describe ScanPackController do

  before(:each) do 
    @user = FactoryGirl.create(:user, :import_orders=> "1")
    sign_in @user
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

   	it "should process order scan for orders having a status of On Hold without active and new products" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'On Hold')

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("On Hold")
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_order_edit")
      expect(result["data"]["order_edit_permission"]).to eq(true)
      expect(result["notice_messages"][0]).to eq("This order is currently on Hold. "+
      	"Please scan or enter confirmation code with order edit permission to continue scanning this order"+
      	" or scan a different order")
    end

   	it "should process order scan for orders having a status of On Hold" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'On Hold')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("On Hold")
      expect(result["data"]["next_state"]).to eq("edit_product_info")
      #expect(result["data"]["inactive_or_new_products"]).to eq()
      expect(result["notice_messages"][0]).to eq("The following items in this order are not Active." +
      	"They may need a barcode or other product info before their status can be changed to Active")
    end

   end

  it "should check for confirmation code when order status is on hold" do
      request.accept = "application/json"
      
      @user.order_edit_confirmation_code = '1234567890'
      @user.save

      @order = FactoryGirl.create(:order, :status=>'On Hold')

      get :order_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_edit_matched"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("ready_for_product")
      expect(session[:order_edit_matched_for_current_user]).to eq(true)
  end

  it "should not check for confirmation code when order status is not on hold" do
      request.accept = "application/json"
      
      @user.order_edit_confirmation_code = '1234567890'
      @user.save

      @order = FactoryGirl.create(:order, :status=>'Scanning Awaiting')

      get :order_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Only orders with status On Hold and has inactive or new products "+ 
            "can use edit confirmation code.")
  end

  it "should not set session variable and return false when confirmation code does not match" do
      request.accept = "application/json"
      
      @user.order_edit_confirmation_code = '1234567890'
      @user.save

      @order = FactoryGirl.create(:order, :status=>'On Hold')

      get :order_edit_confirmation_code, { :confirmation_code => '123456789', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_edit_matched"]).to eq(false)
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_order_edit")
  end
end
