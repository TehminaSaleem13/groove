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
      expect(result["data"]["status"]).to eq("awaiting")
      expect(result["data"]["next_state"]).to eq("ready_for_product")
    end

   	it "should process order scan for orders having a status of Scanned" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'scanned', :scanned_on=> "2013-09-03")

      get :scan_order_by_barcode, { :barcode => 12345678 }

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("scanned")
      expect(result["data"]["next_state"]).to eq("ready_for_order")
      expect(result["data"]["scanned_on"]).to eq("2013-09-03")
      expect(result["notice_messages"][0]).to eq("This order has already been scanned")
    end

   	it "should process order scan for orders having a status of Cancelled" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'cancelled')

      get :scan_order_by_barcode, { :barcode => 12345678 }

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("cancelled")
      expect(result["data"]["next_state"]).to eq("ready_for_order")
      expect(result["notice_messages"][0]).to eq("This order has been cancelled")
    end

   	it "should process order scan for orders having a status of On Hold without active and new products" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("onhold")
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_order_edit")
      expect(result["data"]["order_edit_permission"]).to eq(true)
      expect(result["notice_messages"][0]).to eq("This order is currently on Hold. "+
      	"Please scan or enter confirmation code with order edit permission to continue scanning this order"+
      	" or scan a different order")
    end

   	it "should process order scan for orders having a status of On Hold" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'onhold')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_order_by_barcode, { :barcode => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("onhold")
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_product_edit")
      #expect(result["data"]["inactive_or_new_products"]).to eq()
      expect(result["notice_messages"][0]).to eq("The following items in this order are not Active." +
      	"They may need a barcode or other product info before their status can be changed to Active")
    end

   end

  it "should check for confirmation code when order status is on hold" do
      request.accept = "application/json"
      
      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :order_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_edit_matched"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("ready_for_product")
      @order.reload
      expect(@order.status).to eq("awaiting")
      expect(@order.order_activities.last.action).to eq("Status changed from onhold to awaiting")
      expect(@order.order_activities.last.username).to eq(@other_user.username)
      expect(session[:order_edit_matched_for_current_user]).to eq(true)
  end

  it "should not check for confirmation code when order status is not on hold" do
      request.accept = "application/json"
      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'awaiting')

      get :order_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Only orders with status On Hold and has inactive or new products "+ 
            "can use edit confirmation code.")
  end

  it "should not set session variable and return false when confirmation code does not match" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :order_edit_confirmation_code, { :confirmation_code => '123456789', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_edit_matched"]).to eq(false)
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_order_edit")
      expect(session[:order_edit_matched_for_current_user]).to eq(nil)
  end

  it "should check for product confirmation code when order status is on hold and has inactive or new products" do
      request.accept = "application/json"
      
      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :product_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["product_edit_matched"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("product_edit")
      expect(session[:product_edit_matched_for_current_user]).to eq(true)
  end

  it "should not check for product confirmation code when order status is not on hold" do
      request.accept = "application/json"
      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'awaiting')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :product_edit_confirmation_code, { :confirmation_code => '1234567890', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Only orders with status On Hold and has inactive or new products "+ 
            "can use edit confirmation code.")
  end

  it "should not set session variable and return false when confirmation code does not match" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :product_edit_confirmation_code, { :confirmation_code => '123456789', :order_id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["product_edit_matched"]).to eq(false)
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_product_edit")
      expect(session[:product_edit_matched_for_current_user]).to eq(nil)
  end


  it "should scan product by barcode and order status should be in scanned status when all items are scanned" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
      product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name)


      get :scan_product_by_barcode, { :barcode => '2456789', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      order.reload
      expect(order.status).to eq("awaiting")
  end

  it "should scan product by barcode and order status should still be in awaiting status when there are unscanned items" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'iPhone5C')
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'iPHONE5C1')
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id, :sku=>product_sku.sku, 
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      order.reload
      expect(order.status).to eq("awaiting")
  end

  it "should scan product by barcode and order status should still be in awaiting status when there are unscanned items of the same product" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }
      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      order.reload
      expect(order.status).to eq("awaiting")
      order_item.reload
      expect(order_item.scanned_qty).to eq(2)
      expect(order_item.scanned_status).to eq("partially_scanned")
  end

  it "should scan product by barcode and order status should still be in scanned status when there are no unscanned items"+
     " of the same product" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }
      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }
      get :scan_product_by_barcode, { :barcode => '1234567890', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)

      order.reload
      expect(order.status).to eq("scanned")
      order_item.reload
      expect(order_item.scanned_qty).to eq(3)
      expect(order_item.scanned_status).to eq("scanned")
  end
end

