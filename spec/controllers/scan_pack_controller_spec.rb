require 'spec_helper'

describe ScanPackController do

  before(:each) do 
    @user = FactoryGirl.create(:user, :import_orders=> "1")
    sign_in @user

    @child_item_l = lambda do |name, images, sku, qty_remaining, 
      scanned_qty, packing_placement, kit_packing_placement,
      barcodes, product_id, kit_product_id|
      child_item = Hash.new

      child_item['name'] = name
      child_item['images'] = []
      child_item['sku'] = sku
      child_item['qty_remaining'] = qty_remaining
      child_item['scanned_qty'] = scanned_qty
      child_item['packing_placement'] = packing_placement
      child_item['kit_packing_placement'] =kit_packing_placement
      child_item['barcodes'] = barcodes
      child_item['product_id'] = product_id
      child_item['kit_product_id'] = kit_product_id

      return child_item
    end
    
    @unscanned_item_l = lambda do |name, product_type, images, sku, qty_remaining, 
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items| 

      unscanned_item = Hash.new
      
      unscanned_item["name"] = name
      unscanned_item["product_type"] = product_type
      unscanned_item["images"] = images
      unscanned_item["sku"] = sku
      unscanned_item["qty_remaining"] = qty_remaining
      unscanned_item["scanned_qty"] = scanned_qty
      unscanned_item["packing_placement"] = packing_placement
      unscanned_item["barcodes"] = barcodes
      unscanned_item["product_id"] = product_id
      unscanned_item["order_item_id"] = order_item_id

      if !child_items.nil?
        unscanned_item['child_items'] = child_items
      end

      return unscanned_item
    end

    @scanned_item_l = lambda do |name, product_type, images, sku, qty_remaining, 
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items| 
      scanned_item = Hash.new
      
      scanned_item["name"] = name
      scanned_item["product_type"] = product_type
      scanned_item["images"] = images
      scanned_item["sku"] = sku
      scanned_item["qty_remaining"] = qty_remaining
      scanned_item["scanned_qty"] = scanned_qty
      scanned_item["packing_placement"] = packing_placement
      scanned_item["barcodes"] = barcodes
      scanned_item["product_id"] = product_id
      scanned_item["order_item_id"] = order_item_id

      if !child_items.nil?
        scanned_item['child_items'] = child_items
      end

      return scanned_item
    end

    @expected_result_l = lambda {
      expected_result = Hash.new
      expected_result['status'] = true
      expected_result['error_messages'] = []
      expected_result['success_messages'] = []
      expected_result['notice_messages'] = []

      expected_result['data'] = Hash.new
      expected_result['data']['next_state'] = 'ready_for_product'
      expected_result['data']['unscanned_items'] = []
      expected_result['data']['scanned_items'] = []

      expected_result['data']['most_recent_scanned_products'] = []

      expected_result['data']['next_item_present'] = false

      return expected_result
    }

    @get_response_l = lambda do |response| 
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
    end

    @hash_diff_l = lambda do |hash1, hash2|
      puts "Diffing the two hashes:"
     puts Hash[*(
        (hash2.size > hash1.size)    \
            ? hash2.to_a - hash1.to_a \
            : hash1.to_a - hash2.to_a
        ).flatten].to_s
    end

    @next_item_recommendation_l = lambda do |name, sku, images, scanned_qty, qty, qty_remaining|
      next_item = Hash.new

      next_item['name'] = name
      next_item['sku'] = sku
      next_item['images'] = []
      next_item['scanned_qty'] = scanned_qty
      next_item['qty'] = qty
      next_item['qty_remaining'] = qty_remaining

      next_item
    end

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
      expect(result["data"]["next_state"]).to eq("ready_for_tracking_num")
    end

    it "should process order scan for orders having a status of Awaiting Scanning with some unscanned items" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

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
      expect(result["notice_messages"][0]).to eq("This order is currently on Hold. Please scan or enter "+
        "confirmation code with order edit permission to continue scanning this order or scan a different order.")
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
      expect(result["notice_messages"][0]).to eq("This order was automatically placed on hold because it contains "+
        "items that have a status of New or Inactive. These items may not have barcodes or other information needed "+
        "for processing. Please ask a user with product edit permissions to scan their code so that these items can be "+
        "edited or scan a different order.")
    end

    it "should process order scan for orders having a status of Service issue" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'serviceissue', :scanned_on=> "2013-09-03")
      @user.change_order_status = true
      @user.save

      get :scan_order_by_barcode, { :barcode => 12345678 }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("serviceissue")
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_cos")
      expect(result["notice_messages"][0]).to eq("This order has a pending Service Issue. To clear the Service "+
        "Issue and continue packing the order please scan your confirmation code or scan a different order.")
    end

    it "should process order scan for orders having a status of Service issue" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'serviceissue', :scanned_on=> "2013-09-03")

      get :scan_order_by_barcode, { :barcode => 12345678 }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("serviceissue")
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_cos")
      expect(result["notice_messages"][0]).to eq('This order has a pending Service Issue. To continue with this '+
        'order, please ask another user who has Change Order Status permissions to scan their confirmation code '+
        'and clear the issue. Alternatively, you can pack another order by scanning another order number.')


    end

   end

  it "should check for confirmation code when order status is on hold" do
      request.accept = "application/json"
      
      @other_user = FactoryGirl.create(:user, :email=>'test_other@groovepacks.com', :username=>'test_user')
      
      @other_user.confirmation_code = '12345678901'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :order_edit_confirmation_code, { :confirmation_code => '12345678901', :order_id => @order.id }

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
      
      @other_user.confirmation_code = '12345678901'
      @other_user.edit_products = 1
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :product_edit_confirmation_code, { :confirmation_code => '12345678901', :order_id => @order.id }

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
      expect(order.status).to eq("awaiting")
      order_item.reload
      expect(order_item.scanned_qty).to eq(3)
      expect(order_item.scanned_status).to eq("scanned")
  end

  describe "Change of order status" do
    it "should process confirmation code for change of order status " do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'serviceissue')
      @user.change_order_status = 1
      @user.save
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      post :cos_confirmation_code, { :cos_confirmation_code => '1234567890', :order_id => order.id }


      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("ready_for_order")
      order.reload
      expect(order.status).to eq("awaiting")

    end

    it "should not process confirmation code for change of order status since user does not have change order status" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'serviceissue')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      post :cos_confirmation_code, { :cos_confirmation_code => '1234567890', :order_id => order.id }


      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_cos")
      expect(result["error_messages"].first).to eq(
          "User with confirmation code: 1234567890 does not have permission to change order status")      
    end

    it "should not process confirmation code for change of order status since confirmation code does not exist" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'serviceissue')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      post :cos_confirmation_code, { :cos_confirmation_code => '123456789123', :order_id => order.id }


      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("request_for_confirmation_code_with_cos")
      expect(result["error_messages"].first).to eq(
          "Could not find any user with confirmation code")      
    end
  end

  describe "Product Kit Scan" do
    it "should scan single kits" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product, :packing_placement=>'35')
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'single', :packing_placement=>'40')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)



      get :scan_product_by_barcode, {:barcode => 'IPROTOBAR', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(0)
      expect(result['data']['next_state']).to eq('ready_for_tracking_num')

      order_item_kit.reload
      #expect(order_item_kit.scanned_qty).to eq(1)
      expect(order_item_kit.scanned_status).to eq("scanned")
      order.reload
      expect(order.status).to eq("awaiting")
      order_item.reload
      expect(order_item.scanned_qty).to eq(1)
      expect(order_item.scanned_status).to eq("scanned")
    end

    it "should scan individual kits" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product, :name=>'PRODUCT1', :packing_placement=>40)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'individual', :packing_placement=>50)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'IPROTO1',:packing_placement=>50)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product, :name=>'IPROTO2', :packing_placement=>50)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['scanned_items'].length).to eq(1)
      expect(result['data']['scanned_items'].first['name']).to eq('PRODUCT1')
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(2)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['scanned_items'].length).to eq(3)
      # expect(result['data']['scanned_items'].last['name']).to eq('IPROTO1')
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['scanned_items'].length).to eq(4)
      # expect(result['data']['scanned_items'].last['name']).to eq('iPhone Protection Kit')
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['scanned_items'].length).to eq(4)
      # expect(result['data']['scanned_items'].last['name']).to eq('iPhone Protection Kit')
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO2')
      expect(result['data']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(0)
      expect(result['data']['scanned_items'].length).to eq(4)
      # expect(result['data']['scanned_items'].last['child_items'].length).to eq(2)
      expect(result['data']['next_state']).to eq('ready_for_tracking_num')


      order_item.reload
      expect(order_item.scanned_status).to eq("scanned")
      expect(order_item.scanned_qty).to eq(1)

      order_item_kit_product.reload
      expect(order_item_kit_product.scanned_qty).to eq(2)
      expect(order_item_kit_product.scanned_status).to eq("scanned")
      
      order_item_kit_product2.reload
      expect(order_item_kit_product2.scanned_qty).to eq(2)
      expect(order_item_kit_product2.scanned_status).to eq("scanned")
      
      order_item_kit.reload
      expect(order_item_kit.scanned_status).to eq("scanned")
      expect(order_item_kit.scanned_qty).to eq(2)

      order.reload
      expect(order.status).to eq("awaiting")
      #puts result['data']['unscanned_items'].to_s
      expect(result['data']['unscanned_items'].length).to eq(0)
      expect(result['data']['scanned_items'].length).to eq(4)
      # order_item.reload
      # expect(order_item.scanned_qty).to eq(1)
      # expect(order_item.scanned_status).to eq("scanned")
    end

    it "should split and scan kits" do
      request.accept = "application/json"
      
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product, :name=>'iPhone 5S', :packing_placement=>20)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends', :packing_placement=>30)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Protection Sheet', :packing_placement=>30)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product, :name=>'Screen Wiper', :packing_placement=>40)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

      kit_product3 = FactoryGirl.create(:product, :name=>'Instruction Manual', :packing_placement=>50)
      kit_product3_sku = FactoryGirl.create(:product_sku, :product=> kit_product3, :sku=> 'IPROTO3')
      kit_product3_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product3, :barcode => 'KITITEM3')

      product_kit_sku3 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product3.id)
      order_item_kit_product3 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku3)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
              :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)


      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['unscanned_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['name']).to eq('iPhone Protection Kit')
      expect(result['data']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('Protection Sheet')
      expect(result['data']['unscanned_items'].last['product_type']).to eq('single')
      expect(result['data']['unscanned_items'].last['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')
      expect(result['data']['next_state']).to eq('ready_for_product')

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('Screen Wiper')
      expect(result['data']['next_state']).to eq('ready_for_product')


      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')

      get :scan_product_by_barcode, {:barcode => 'KITITEM3', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')


      get :scan_product_by_barcode, {:barcode => 'KITITEM3', :order_id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['unscanned_items'].length).to eq(0)
      expect(result['data']['next_state']).to eq('ready_for_tracking_num')

      order.reload
      expect(order.status).to eq("awaiting")
    end

    it "should reset scanned status of order" do
      request.accept = "application/json"
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name, 
                    :scanned_status=>'scanned', :scanned_qty => 1)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku, :scanned_status=>'scanned', :scanned_qty=>1)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2, :scanned_status=>'scanned', :scanned_qty=>1)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name,
               :scanned_status=>'scanned', :scanned_qty => 1)

      put :reset_order_scan, {:order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['next_state']).to eq('ready_for_order')
      order.reload
      expect(order.status).to eq('awaiting')

      order_item.reload
      expect(order_item.scanned_status).to eq('unscanned')
      expect(order_item.scanned_qty).to eq(0)

      order_item2.reload
      expect(order_item2.scanned_status).to eq('unscanned')
      expect(order_item2.scanned_qty).to eq(0)
      
      order_item_kit_product.reload
      expect(order_item_kit_product.scanned_status).to eq('unscanned')
      expect(order_item_kit_product.scanned_qty).to eq(0)     

      order_item_kit_product2.reload
      expect(order_item_kit_product2.scanned_status).to eq('unscanned')
      expect(order_item_kit_product2.scanned_qty).to eq(0)   
    end

    it "should not reset scanned status of order" do
      request.accept = "application/json"
      order = FactoryGirl.create(:order, :status=>'scanned')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name, 
                    :scanned_status=>'scanned', :scanned_qty => 1)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku, :scanned_status=>'scanned', :scanned_qty=>1)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2, :scanned_status=>'scanned', :scanned_qty=>1)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name,
               :scanned_status=>'scanned', :scanned_qty => 1)

      put :reset_order_scan, {:order_id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
    end

    it "should scan tracking number of an order" do
      request.accept = "application/json"
      order = FactoryGirl.create(:order, :status=>'awaiting')

      put :scan_tracking_num, {:order_id => order.id, :tracking_num=>'1234567890' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      order.reload
      expect(order.status).to eq('scanned')
      #expect()
    end

    it "should scan orders with multiple kit products" do

      request.accept = "application/json"
      
      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      1, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 1, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)
      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 1, 1, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item_present'] = true
      expected_result['data']['next_item'] = Hash.new
      expected_result['data']['next_item']['name'] = 'Apple iPhone 5C'
      expected_result['data']['next_item']['sku'] = 'IPROTO1'
      expected_result['data']['next_item']['images'] = []
      expected_result['data']['next_item']['scanned_qty'] = 1
      expected_result['data']['next_item']['qty'] = 2
      expected_result['data']['next_item']['qty_remaining'] = 1

      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      expected_result['data']['next_state'] ='ready_for_tracking_num'

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 0, 
      2, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 0, 2, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)
      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 0, 2, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #order status
      order.reload
      expect(order.status).to eq('awaiting')
    end

    it "should scan orders with multiple kit products" do

      request.accept = "application/json"
      
      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      1, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 1, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)
      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 1, 1, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item_present'] = true

      expected_result['data']['next_item'] = Hash.new
      expected_result['data']['next_item']['name'] = 'Apple iPhone 5C'
      expected_result['data']['next_item']['sku'] = 'IPROTO1'
      expected_result['data']['next_item']['images'] = []
      expected_result['data']['next_item']['scanned_qty'] = 1
      expected_result['data']['next_item']['qty'] = 2
      expected_result['data']['next_item']['qty_remaining'] = 1

      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      expected_result['data']['next_state'] ='ready_for_tracking_num'

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 0, 
      2, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 0, 2, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)
      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 0, 2, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #order status
      order.reload
      expect(order.status).to eq('awaiting')
    end

    it "should scan orders with multiple kit products and quantities" do

      request.accept = "application/json"
      
      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id, :qty=> 3)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id, :qty=> 4)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 1, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 1, 1, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item_present'] = true
      expected_result['data']['next_item'] = Hash.new
      expected_result['data']['next_item']['name'] = 'Apple iPhone 5S'
      expected_result['data']['next_item']['sku'] = 'IPHONE5S'
      expected_result['data']['next_item']['images'] = []
      expected_result['data']['next_item']['scanned_qty'] = 1
      expected_result['data']['next_item']['qty'] = 2
      expected_result['data']['next_item']['qty_remaining'] = 1
      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
      
      # expected_result['data']['next_item_present'] = true
      # expected_result['data']['next_item'] = Hash.new
      # expected_result['data']['next_item']['name'] = 'Apple iPhone 5S'
      # expected_result['data']['next_item']['sku'] = 'IPHONE5S'
      # expected_result['data']['next_item']['images'] = []
      # expected_result['data']['next_item']['scanned_qty'] = 1
      # expected_result['data']['next_item']['qty'] = 2
      # expected_result['data']['next_item']['qty_remaining'] = 1
      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3, 
      1, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3, 
      1, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          1, 4, 3)
      expected_result['data']['next_item_present'] = true
      
      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2, 
      2, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          2, 4, 2)
      expected_result['data']['next_item_present'] = true


      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(1)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1, 
      3, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1, 
      3, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 4, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          3, 4, 1)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(1)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      # child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      # 3, 50, 50,
      # kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, nil)

      expected_result['data']['unscanned_items'] << unscanned_item

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      4, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 5, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3, 
      5, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3, 
      5, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 6, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          5, 8, 3)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2, 
      6, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2, 
      6, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 7, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
      
      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          6, 8, 2)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))


      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1, 
      7, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1, 
      7, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 8, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product2.name, 'IPROTO2', [], 
          7, 8, 1)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM2
      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6, 
      0, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)
      expect(order_item_kit.kit_split_scanned_qty).to eq(0)
      expect(order_item_kit.scanned_qty).to eq(0)



      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 5, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 5, 
      1, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 5, 1, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product.name, 'IPROTO1', [], 
          1, 6, 5)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 4, 
      2, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 4, 
      2, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 2, 0, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 4, 2, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product.name, 'IPROTO1', [], 
          2, 6, 4)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      3, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3, 
      3, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 3, 3, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
      
      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product.name, 'IPROTO1', [], 
          3, 6, 3)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2, 
      4, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2, 
      4, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 2, 4, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
      
      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product.name, 'IPROTO1', [], 
          4, 6, 2)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      5, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['unscanned_items'] << unscanned_item


      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1, 
      5, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 1, 1, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 1, 5, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
      
      expected_result['data']['next_item'] = @next_item_recommendation_l.call(kit_product.name, 'IPROTO1', [], 
          5, 6, 1)
      expected_result['data']['next_item_present'] = true

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #scanned barcode: KITITEM1
      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      result = @get_response_l.call(response)
      
      expected_result = @expected_result_l.call()

      order_item_kit.reload

      expect(order_item_kit.kit_split_qty).to eq(2)

      expected_result['data']['next_state'] = 'ready_for_tracking_num'

      scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [], 
              'IPHONE5S', 0, 2, 50, product.product_barcodes,
              product.id, order_item.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      child_items = []

      child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 0, 
      6, 50, 50,
      kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

      child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0, 
      8, 50, 50,
      kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

      scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [], 
              'IPROTO', 0, 2, 50, product_kit.product_barcodes,
              product_kit.id, order_item_kit.id, child_items)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [], 
              'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
              kit_product2.id, order_item2.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      scanned_item = @scanned_item_l.call(kit_product.name, 'single', [], 
              'IPROTO1', 0, 6, 50, kit_product.product_barcodes,
              kit_product.id, order_item_kit.id, nil)

      expected_result['data']['scanned_items'] << scanned_item

      expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

      expect(result).to eq(JSON.parse(expected_result.to_json))

      #order status
      order.reload
      expect(order.status).to eq('awaiting')
    end


    it "should scan orders with multiple kit products and adjust inventory accordingly" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      product_kit_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product_kit,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')
      kit_product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id, :qty=>1)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')
      kit_product2_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)
    
      
      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(1)

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(1)


      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      order.reload
      order.status = 'scanned'
      order.save

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product2_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(2)
    end

    it "should scan orders with multiple kit products and adjust inventory accordingly when some kits are not split" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      product_kit_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product_kit,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')
      kit_product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id, :qty=>1)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')
      kit_product2_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)
    
      
      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      get :scan_product_by_barcode, {:barcode => 'KITITEM1', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(1)

      get :scan_product_by_barcode, {:barcode => 'KITITEM2', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(1)


      get :scan_product_by_barcode, {:barcode => 'IPROTOBAR', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(1)


      order.reload
      order.status = 'scanned'
      order.save

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(24)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => product_kit_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(1)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(24)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(1)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(24)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product2_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(1)
    end

    it "should scan orders with multiple kit products and adjust inventory accordingly when all depends kits are not split" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      #create an order with one order item which is an individual product,
      #another is a kit which has a quantity of 2 and depedently splittable.
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      product_kit_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product_kit,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')
      kit_product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id, :qty=>1)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')
      kit_product2_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)
    
      
      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      
      #scanned barcode: BARCODE1
      get :scan_product_by_barcode, {:barcode => 'BARCODE1', :order_id => order.id }

      get :scan_product_by_barcode, {:barcode => 'IPROTOBAR', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)


      get :scan_product_by_barcode, {:barcode => 'IPROTOBAR', :order_id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)


      order.reload
      order.status = 'scanned'
      order.save

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(23)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => product_kit_inv_wh.id)
      expect(sold_inv_wh.count).to eq(1)
      expect(sold_inv_wh.first.sold_qty).to eq(2)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product_inv_wh.id)
      expect(sold_inv_wh.count).to eq(0)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(25)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      sold_inv_wh = SoldInventoryWarehouse.where(:product_inventory_warehouses_id => kit_product2_inv_wh.id)
      expect(sold_inv_wh.count).to eq(0)

    end

  end
end

