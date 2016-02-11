require 'rails_helper'
#include Devise::TestHelpers

RSpec.describe ScanPackController, :type => :controller do

  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @scanpacksetting = ScanPackSetting.first
    @scanpacksetting.post_scanning_option = "Record"
    @scanpacksetting.save
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)

    #@user_role =FactoryGirl.create(:role, :name=>'scan_pack', :import_orders=>true)
    @user = FactoryGirl.create(:user, :username=>"scan_pack_spec_user", :name=>'Scan Pack user', 
      :role => Role.find_by_name('Scan & Pack User'))
    # sign_in @user
    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in :user, @user 

    #@request.env["devise.mapping"] = Devise.mappings[:user]

    @child_item_l = lambda do |name, images, sku, qty_remaining,
      scanned_qty, packing_placement, kit_packing_placement,
      barcodes, product_id, kit_product_id|
      child_item = Hash.new

      child_item['name'] = name
      child_item['instruction'] = nil
      child_item['confirmation'] = false
      child_item['images'] = []
      child_item['sku'] = sku
      child_item['packing_placement'] = packing_placement
      child_item['barcodes'] = barcodes
      child_item['product_id'] = product_id
      child_item['skippable'] = false
      child_item['record_serial'] = false
      child_item['order_item_id'] = 0
      child_item['type_scan_enabled'] = 'on'
      child_item['click_scan_enabled'] = 'on'
      child_item['scanned_qty'] = scanned_qty
      child_item['qty_remaining'] = qty_remaining
      child_item['kit_packing_placement'] = kit_packing_placement
      child_item['kit_product_id'] = kit_product_id

      return child_item
    end

    @unscanned_item_l = lambda do |name, product_type, images, sku, qty_remaining,
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items,instruction,confirmation|

      unscanned_item = Hash.new

      unscanned_item["name"] = name
      unscanned_item['instruction'] = instruction
      unscanned_item['confirmation'] = confirmation
      unscanned_item["images"] = images
      unscanned_item["sku"] = sku
      unscanned_item["packing_placement"] = packing_placement
      unscanned_item["barcodes"] = barcodes
      unscanned_item["product_id"] = product_id
      unscanned_item['skippable'] = false
      unscanned_item['record_serial'] = false
      unscanned_item['type_scan_enabled'] = 'on'
      unscanned_item['click_scan_enabled'] = 'on'
      unscanned_item["order_item_id"] = order_item_id
      unscanned_item["product_type"] = product_type
      unscanned_item["qty_remaining"] = qty_remaining
      unscanned_item["scanned_qty"] = scanned_qty

      if !child_items.nil?
        unscanned_item['child_items'] = child_items
        child_items.each do |child_item|
          child_item['order_item_id'] = order_item_id
        end
      end

      return unscanned_item
    end

    @scanned_item_l = lambda do |name, product_type, images, sku, qty_remaining,
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items|
      scanned_item = Hash.new

      scanned_item["name"] = name
      scanned_item['instruction'] = nil
      scanned_item['confirmation'] = false
      scanned_item["images"] = images
      scanned_item["sku"] = sku
      scanned_item["packing_placement"] = packing_placement
      scanned_item["barcodes"] = barcodes
      scanned_item["product_id"] = product_id
      scanned_item['skippable'] = false
      scanned_item['record_serial'] = false
      scanned_item['type_scan_enabled'] = 'on'
      scanned_item['click_scan_enabled'] = 'on'
      scanned_item["order_item_id"] = order_item_id
      scanned_item["product_type"] = product_type
      scanned_item["qty_remaining"] = qty_remaining
      scanned_item["scanned_qty"] = scanned_qty

      if !child_items.nil?
        scanned_item['child_items'] = child_items
        child_items.each do |child_item|
          child_item['order_item_id'] = order_item_id
        end
      end

      return scanned_item
    end

    @expected_result_l = lambda do |order, kit_product_barcode|
      expected_result = Hash.new
      expected_result['status'] = true
      expected_result['error_messages'] = []
      expected_result['success_messages'] = []
      expected_result['notice_messages'] = []

      order.reload
      kit_product_barcode.reload
      expected_result['data'] = Hash.new
      expected_result['data']['next_state'] = 'scanpack.rfp.default'
      expected_result['data']['serial'] = Hash.new
      expected_result['data']['serial']['ask'] = false
      expected_result['data']['serial']['clicked'] = false
      expected_result['data']['serial']['barcode'] = kit_product_barcode.barcode
      expected_result['data']['serial']['order_id'] = order.id.to_s
      expected_result['data']['order_num'] = order.increment_id.to_s
      expected_result['data']['order'] = order.attributes
      expected_result['data']['order']['increment_id'] = order.increment_id.to_s
      expected_result['data']['order']['packing_user_id'] = @user.id
      expected_result['data']['order']['unscanned_items'] = []
      expected_result['data']['order']['scanned_items'] = []

      #expected_result['data']['most_recent_scanned_products'] = []

      #expected_result['data']['next_item_present'] = false

      return expected_result
    end

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

    @next_item_recommendation_l = lambda do |item|
      next_item = item
      next_item['qty'] = next_item['scanned_qty'] + next_item['qty_remaining']
     return next_item
    end

  end

  describe "Order Scan" do

    it "should not scan with no state" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order)

      get :scan_barcode

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Please specify a state")
    end

   	it "should not scan orders with no barcode" do
      request.accept = "application/json"
      request.env["devise.mapping"] = Devise.mappings[:user]
      @order = FactoryGirl.create(:order)

      get :scan_barcode, {:state => "scanpack.rfo"}

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"][0]).to eq("Please specify a barcode to scan the order")
    end

    it "should process order scan with post_scanning_option set" do
      request.accept = "application/json"


      order = FactoryGirl.create(:order, increment_id: '123-456', tracking_num: nil)

      # FOR Verify
      @scanpacksetting.post_scanning_option = 'Verify'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => '#123-456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
      expect(result['data']['next_state']).to eq 'scanpack.rfp.no_tracking_info'
      expect(order.order_activities.pluck :action).to include("Tracking information was not imported with this order so the shipping label could not be verified ")
      expect(order.status).to eq 'awaiting'

      # FOR Verify with Tracking number
      order1 = FactoryGirl.create(:order, increment_id: '#1111', tracking_num: '1234')
      @scanpacksetting.post_scanning_option = 'Verify'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => '#1111' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order1.increment_id
      expect(result['data']['next_state']).to eq 'scanpack.rfp.verifying'
      expect(order.status).to eq 'awaiting'

      # FOR Record
      @scanpacksetting.post_scanning_option = 'Record'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => '#123456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result['data']['next_state']).to eq 'scanpack.rfp.recording'
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
      expect(order.status).to eq 'awaiting'

      # For PackingSlip
      @scanpacksetting.post_scanning_option = 'PackingSlip'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => '123-456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
      expect(result['data']['next_state']).to eq 'scanpack.rfo'
      expect(GenerateBarcode.first.current_increment_id).to eq order.increment_id
      expect(order.status).to eq 'awaiting'

      # For PackingSlip with packing size 4x6 and orientation landscape
      order4 = FactoryGirl.create(:order, increment_id: '#432432432', tracking_num: '3424324')
      @generalsetting.packing_slip_size = '4 x 6'
      @generalsetting.packing_slip_orientation = 'landscape'
      @generalsetting.save!
      @scanpacksetting.post_scanning_option = 'PackingSlip'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => '#432432432' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order4.increment_id
      expect(result['data']['next_state']).to eq 'scanpack.rfo'
      expect(GenerateBarcode.last.next_order_increment_id).to eq order4.increment_id
      expect(order4.status).to eq 'awaiting'

      # For Any Other
      #Commenting due to build failure on bamboo
      # order1 = FactoryGirl.create(:order, increment_id: '#2222')
      # @scanpacksetting.post_scanning_option = 'any'
      # @scanpacksetting.save!
      # get :scan_barcode, { :state => "scanpack.rfo", :input => '2222' }
      # expect(response.status).to eq(200)
      # result = JSON.parse(response.body)
      # expect(result["data"]["order"].present?).to eq true
      # expect(result["data"]["order"]["increment_id"]).to eq order1.increment_id
      # expect(result['data']['next_state']).to eq 'scanpack.rfo'
      # expect(GenerateBarcode.last.current_increment_id).to eq order1.increment_id
      
      # For NONE
      check_none = FactoryGirl.create(:order, increment_id: '#none')
      @scanpacksetting.post_scanning_option = 'None'
      @scanpacksetting.save!
      get :scan_barcode, { :state => "scanpack.rfo", :input => 'none' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq check_none.increment_id
      expect(result['data']['next_state']).to eq 'scanpack.rfo'
      expect(order.reload.status).to eq 'scanned'
    end

    it "should process order scan by both hypenated and non hyphenated barcode plus including # symbol" do
      request.accept = "application/json"

      order = FactoryGirl.create(:order, :increment_id=>'123-456')

      get :scan_barcode, { :state => "scanpack.rfo", :input => '#123-456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id

      get :scan_barcode, { :state => "scanpack.rfo", :input => '#123456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id

      get :scan_barcode, { :state => "scanpack.rfo", :input => '123-456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
    end

    it "should process order scan with multiple regexp keywords present in input" do
      request.accept = "application/json"

      order = FactoryGirl.create(:order, :increment_id=>'++-..123--++456')

      get :scan_barcode, { :state => "scanpack.rfo", :input => '#++-..123--++456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
    end

    it "should process order scan with barcode slip generation " do
      request.accept = "application/json"
      @scanpacksetting.post_scanning_option = "PackingSlip"
      @scanpacksetting.save!

      order = FactoryGirl.create(:order, :increment_id=>'123-456')

      get :scan_barcode, { :state => "scanpack.rfo", :input => '#123-456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
      expect(GenerateBarcode.first.current_increment_id).to eq order.increment_id
    end

    it "should process order scan for the matched input first and add other founded orders to cue" do
      request.accept = "application/json"
      increment_ids = ['MT3004', '#MT3004', 'MT3-004', '#MT3-004']

      orders = increment_ids.each_with_index.reduce([]) do |arr, (increment_id, index)|
        arr[index] = FactoryGirl.create(:order, increment_id: increment_id)
        arr
      end

      orders.each do |order|
        get :scan_barcode, { :state => "scanpack.rfo", :input => order.increment_id }
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result["data"]["order"].present?).to eq true
        expect(result["data"]["order"]["increment_id"]).to eq order.increment_id
        expect(result["data"]["matched_orders"].count).to eq 4
        expect(
          result["data"]["matched_orders"].map{|e| e['increment_id']} - 
          [
            orders[0].increment_id, orders[1].increment_id,
            orders[2].increment_id, orders[3].increment_id
          ]
          ).to eq []
      end
    end

    it "should process order scan by both tracking number and order number if scan_by_tracking_number is enabled" do
      request.accept = "application/json"

      @scanpacksetting.scan_by_tracking_number = true
      @scanpacksetting.save
      order1 = FactoryGirl.create(:order, :tracking_num=>'11223344556677889900')
      order2 = FactoryGirl.create(:order, :increment_id=>'1234567890123')

      get :scan_barcode, { :state => "scanpack.rfo", :input => '11223344556677889900' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order1.increment_id

      get :scan_barcode, { :state => "scanpack.rfo", :input => 1234567890123 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order"].present?).to eq true
      expect(result["data"]["order"]["increment_id"]).to eq order2.increment_id
    end

    it "should process order scan by scan verifying with tracking_number or confirmation_code" do
      request.accept = "application/json"

      @scanpacksetting.scan_by_tracking_number = true
      @scanpacksetting.save

      @user.confirmation_code = '123456'
      @user.save!

      order = FactoryGirl.create(:order, tracking_num: '11223344556677889900', increment_id: '123-456')
      order2 = FactoryGirl.create(:order, increment_id: '#123-456')
      order3 = FactoryGirl.create(:order, increment_id: '#111-456')

      get :scan_barcode, { id: order.id, :state => "scanpack.rfp.verifying", :input => '11223344556677889900' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(order.order_activities.pluck :action).to include("Shipping Label Verified: 11223344556677889900")

      get :scan_barcode, { id: order2.id, :state => "scanpack.rfp.verifying", :input => '123456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_complete"]).to eq true

      # IF already scanned
      get :scan_barcode, { id: order2.id, :state => "scanpack.rfp.verifying", :input => '123456' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["data"]["order_complete"]).to eq nil

      # If input not present
      get :scan_barcode, { id: order3.id, :state => "scanpack.rfp.verifying", :input => nil }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include "Tracking number does not match."
      expect(result["data"]['next_state']).to eq 'scanpack.rfp.no_match'

      # If id nil
      get :scan_barcode, { id: nil, :state => "scanpack.rfp.verifying", :input => 'invalid' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result['error_messages']).to include("Could not find order with id: "+ nil.to_s)
    end

    it "should process order scan for no_tracking_info" do
      request.accept = "application/json"

      @user.confirmation_code = '123456'
      @user.save!

      order = FactoryGirl.create(:order, increment_id: '123-456')
      order2 = FactoryGirl.create(:order, increment_id: '#123-456')

      get :scan_barcode, { id: order.id, :state => "scanpack.rfp.no_tracking_info", input: ''}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_complete"]).to eq true
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")

      get :scan_barcode, { id: order2.id, :state => "scanpack.rfp.no_tracking_info", :input => '123456342' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.no_tracking_info")
    end

    it "should process order scan for no match" do
      request.accept = "application/json"

      @scanpacksetting.scan_by_tracking_number = true
      @scanpacksetting.save!

      @generalsetting.strict_cc = false
      @generalsetting.save!

      @user.confirmation_code = '123456'
      @user.save!

      order = FactoryGirl.create(:order, increment_id: '123-456')
      order2 = FactoryGirl.create(:order, tracking_num: '11223344556677889900', increment_id: '#123-456')
      order3 = FactoryGirl.create(:order, increment_id: '#113-456')
      order4 = FactoryGirl.create(:order, increment_id: '#111-456')

      get :scan_barcode, { id: order.id, :state => "scanpack.rfp.no_match", input: '123456'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_complete"].present?).to eq true
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(order.order_activities.pluck :action).to include("The correct shipping label was not verified at the time of packing."\
      " Confirmation code for user #{@user.username} was scanned")

      get :scan_barcode, { id: order2.id, :state => "scanpack.rfp.no_match", :input => '11223344556677889900' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["order_complete"]).to eq true
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")

      get :scan_barcode, { id: order3.id, :state => "scanpack.rfp.no_match", :input => '' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["matched"]).to eq(false)
      expect(result["data"]["order_complete"]).to eq true
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")

      @generalsetting.strict_cc = true
      @generalsetting.save!
      get :scan_barcode, { id: order4.id, :state => "scanpack.rfp.no_match", :input => '' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["matched"]).to eq(false)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.no_match")
    end

   	it "should process order scan for orders having a status of Awaiting Scanning" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order)

      get :scan_barcode, { :state => "scanpack.rfo", :input => 12345678 }

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]['order']["status"]).to eq("awaiting")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.recording")
    end

    it "should process order scan for orders having a status of Awaiting Scanning with some unscanned items" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, { :state=> "scanpack.rfo", :input => 12345678 }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("awaiting")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.default")
    end

   	it "should process order scan for orders having a status of Scanned" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'scanned', :scanned_on=> "2013-09-03")

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]['order']["status"]).to eq("scanned")
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(result["notice_messages"][0]).to eq("This order has already been scanned")
    end


   	it "should process order scan for orders having a status of Cancelled" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'cancelled')

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

	    expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("cancelled")
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(result["notice_messages"][0]).to eq("This order has been cancelled")
    end

   	it "should process order scan for orders having a status of On Hold without active and new products" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("onhold")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.order_edit")
      expect(result["notice_messages"][0]).to eq("This order is currently on Hold. Please scan or enter "+
        "confirmation code with order edit permission to continue scanning this order or scan a different order.")
    end

   	it "should process order scan for orders having a status of On Hold" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'onhold', store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

	  expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("onhold")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.product_edit")
      #expect(result["data"]["inactive_or_new_products"]).to eq()
      expect(result["notice_messages"][0]).to eq("This order was automatically placed on hold because it contains "+
        "items that have a status of New or Inactive. These items may not have barcodes or other information needed "+
        "for processing. Please ask a user with product edit permissions to scan their code so that these items can be "+
        "edited or scan a different order.")
    end

    it "should process order scan for orders having a status of Service issue" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'serviceissue', :scanned_on=> "2013-09-03")
      change_order_status = @user.role.change_order_status
      @user.role.update_attribute(:change_order_status, true)

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("serviceissue")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.cos")
      expect(result["notice_messages"][0]).to eq("This order has a pending Service Issue. To clear the Service "+
        "Issue and continue packing the order please scan your confirmation code or scan a different order.")
      @user.role.update_attribute(:change_order_status, change_order_status)
    end

    it "should process order scan for orders having a status of Service issue" do
      request.accept = "application/json"

      @order = FactoryGirl.create(:order, :status=>'serviceissue', :scanned_on=> "2013-09-03")

      get :scan_barcode, {:state=>'scanpack.rfo', :input => 12345678 }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["status"]).to eq("serviceissue")
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.cos")
      expect(result["notice_messages"][0]).to eq('This order has a pending Service Issue. To continue with this '+
        'order, please ask another user who has Change Order Status permissions to scan their confirmation code '+
        'and clear the issue. Alternatively, you can pack another order by scanning another order number.')


    end

   end

  it "should ADD note" do
    request.accept = "application/json"

    @generalsetting.update_attribute(:email_address_for_packer_notes, 'groovetest123456@gmail.com')
    order = FactoryGirl.create(:order, :increment_id=>'123-456')

    get :add_note, {:id => order.id, note: 'Hello'}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['success_messages']).to include 'Note from Packer saved successfully'

    # If both id and note is nil
    get :add_note, {:id => nil, note: nil}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['error_messages']).to include 'Order id and note from packer required'

    # If only id is invalid
    get :add_note, {:id => 'invalid_id', note: 'Hello'}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['error_messages']).to include "Could not find order with id: invalid_id"
    
    # If Email not present
    @generalsetting.update_attribute(:email_address_for_packer_notes, nil)
    get :add_note, {:id => order.id, note: 'Hello'}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['error_messages']).to include 'Email not found for notification settings.'

  end

  it "should check for confirmation code when order status is on hold" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, :username=>'test_user', 
        :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      # @other_user.confirmation_code = '12345678902'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold', increment_id: '1234')
      order2 = FactoryGirl.create(:order, :status=>'onhold', increment_id: '4567')

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.order_edit', :input => '12345678902', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.default")
      @order.reload
      expect(@order.status).to eq("awaiting")
      expect(@order.order_activities.last.action).to eq("Status changed from onhold to awaiting")
      expect(@order.order_activities.last.username).to eq(@other_user.username)
      expect(session[:order_edit_matched_for_current_user]).to eq(true)

      # IF confimation code does not match
      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.order_edit', :input => 'invalid', :id => order2.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")

      # IF input is not present
      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.order_edit', :input => '', :id => order2.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result["error_messages"]).to include("Please specify confirmation code and order id to confirm purchase code")

      # IF order not found is not present
      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.order_edit', :input => '12345678902', :id => 'any' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["error_messages"]).to include("Could not find order with id: any")
  end

  it "should not check for confirmation code when order status is not on hold" do
      request.accept = "application/json"
      @other_user = FactoryGirl.create(:user, 
        :username => 'test_user', :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      # @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'awaiting')

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.order_edit', :input => '1234567890', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['notice_messages'][0]).to eq("Order with number 1234567890 cannot be found. It may not have been imported yet")
      expect(result["error_messages"][0]).to eq("Only orders with status On Hold and has inactive or new products "+
            "can use edit confirmation code.")
  end

  it "should not set session variable when confirmation code does not match" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, :username=>'test_user', 
        :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      # @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold')

      get :scan_barcode, {:state=>'scanpack.rfo', :input => '123456789', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(session[:order_edit_matched_for_current_user]).to eq(nil)
  end

  it "should check for  when order status is on hold and has inactive or new products" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, 
        :username=>'test_user', 
        :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')
      add_edit_products = @other_user.role.add_edit_products
      @other_user.role.update_attribute(:add_edit_products, true)

      # @other_user.confirmation_code = '12345678901'
      @other_user.role.add_edit_products = 1
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold', store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.product_edit', :input => '12345678901', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.product_edit")
      expect(session[:product_edit_matched_for_current_user]).to eq(true)
      @other_user.role.update_attribute(:add_edit_products, add_edit_products)
  end

  it "should not check for product confirmation code when order status is not on hold" do
      request.accept = "application/json"
      @other_user = FactoryGirl.create(:user, :username=>'test_user', 
        :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      # @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'awaiting', store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.product_edit', :input => '1234567890', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['notice_messages'][0]).to eq("Order with number 1234567890 cannot be found. It may not have been imported yet")
      expect(result["error_messages"][0]).to eq("Only orders with status On Hold and has inactive or new products "+
            "can use edit confirmation code.")
  end

  it "should not set session variable when confirmation code does not match" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, 
        :username=>'test_user', :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      # @other_user.confirmation_code = '1234567890'
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold', store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.product_edit', :input => '123456789', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(session[:product_edit_matched_for_current_user]).to eq(nil)
  end

  it "should not set session variable when user does not have enough permissions" do
      request.accept = "application/json"

      @other_user = FactoryGirl.create(:user, 
        :username=>'test_user', :role => Role.find_by_name('Scan & Pack User'), :confirmation_code => '12345678902')

      @other_user.confirmation_code = '12345678902'
      @other_user.role.add_edit_products = false
      @other_user.role.save
      @other_user.save

      @order = FactoryGirl.create(:order, :status=>'onhold', store: Store.first)
      @orderitem = FactoryGirl.create(:order_item, :order=>@order)
      @order.addnewitems

      get :scan_barcode, {:state=>'scanpack.rfp.confirmation.product_edit', :input => '12345678902', :id => @order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.product_edit")
      expect(session[:product_edit_matched_for_current_user]).to eq(nil)
  end

  it "should scan product by barcode and order status should be in scanned status when all items are scanned" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', store: store)
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inventory_warehouse = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
      product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")
      product_inventory_warehouse2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '2456789', :id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      order.reload
      expect(order.status).to eq("awaiting")
  end

  # it "should scan product by barcode and updates the order activity log after each product is scanned, with post_scanning_option" do
  #     request.accept = "application/json"

  #     order = FactoryGirl.create(:order, :status=>'awaiting', store: Store.first)

  #     product = FactoryGirl.create(:product)
  #     product_sku = FactoryGirl.create(:product_sku, :product=> product)
  #     product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>"987654321")
  #     order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

  #     product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
  #     product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, sku: 'iPhone5C')
  #     product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")
  #     order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name)

  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '987654321', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '2456789', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     # POST SCANNING
  #     # None
  #     @scanpacksetting.update_attribute(:post_scanning_option, 'None')
  #     product3 = FactoryGirl.create(:product)
  #     product_sku3 = FactoryGirl.create(:product_sku, :product=> product3, sku: 'ps1')
  #     product_barcode3 = FactoryGirl.create(:product_barcode, :product=> product3, :barcode=>"ps1")
  #     order_item3 = FactoryGirl.create(:order_item, :product_id=>product3.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product3.name)
  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'ps1', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     # Verify without tracking number
  #     @scanpacksetting.update_attribute(:post_scanning_option, 'Verify')
  #     product4 = FactoryGirl.create(:product)
  #     product_sku4 = FactoryGirl.create(:product_sku, :product=> product4, sku: 'ps2')
  #     product_barcode4 = FactoryGirl.create(:product_barcode, :product=> product4, :barcode=>"ps2")
  #     order_item3 = FactoryGirl.create(:order_item, :product_id=>product4.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product4.name)
  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'ps2', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     # PackingSlip
  #     @scanpacksetting.update_attribute(:post_scanning_option, 'PackingSlip')
  #     product5 = FactoryGirl.create(:product)
  #     product_sku5 = FactoryGirl.create(:product_sku, :product=> product5, sku: 'ps3')
  #     product_barcode5 = FactoryGirl.create(:product_barcode, :product=> product5, :barcode=>"ps3")
  #     order_item5 = FactoryGirl.create(:order_item, :product_id=>product5.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product5.name)
  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'ps3', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     # Any Other than None
  #     @scanpacksetting.update_attribute(:post_scanning_option, 'Any')
  #     product6 = FactoryGirl.create(:product)
  #     product_sku6 = FactoryGirl.create(:product_sku, :product=> product6, sku: 'ps4')
  #     product_barcode6 = FactoryGirl.create(:product_barcode, :product=> product6, :barcode=>"ps4")
  #     order_item6 = FactoryGirl.create(:order_item, :product_id=>product6.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product6.name)
  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'ps4', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)

  #     # Verify with Tracking number
  #     order.update_attribute(:tracking_num, '1232121')
  #     @scanpacksetting.update_attribute(:post_scanning_option, 'Verify')
  #     product7 = FactoryGirl.create(:product)
  #     product_sku7 = FactoryGirl.create(:product_sku, :product=> product7, sku: 'ps5')
  #     product_barcode7 = FactoryGirl.create(:product_barcode, :product=> product7, :barcode=>"ps5")
  #     order_item7 = FactoryGirl.create(:order_item, :product_id=>product7.id,
  #                   :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product7.name)
  #     get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'ps5', :id => order.id }
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result["status"]).to eq(true)
  #     expect(result['data']['next_state']).to eq('scanpack.rfp.verifying')
  # end

  it "should scan product with typein count" do
      request.accept = "application/json"

      order = FactoryGirl.create(:order, :status=>'awaiting', store: Store.first)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>"987654321")
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>30000, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      t1 = Time.now
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '987654321', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      t2 = Time.now - t1

      t1 = Time.now
      get :type_scan, {
        :state=>'scanpack.rfp.default', :input => '987654321', :id => order.id ,
        next_item: result['data']['order']['next_item'], count: 20000
      }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(order_item.reload.scanned_qty).to eq(20001)
      #should take at max 10times more time than single count scan
      expect(0..(10*t2)).to cover(Time.now - t1)
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

      # IF item skippable
      @scanpacksetting.skip_code_enabled = true
      @scanpacksetting.skip_code = 'skippable'
      @scanpacksetting.save!
      product.is_skippable = true
      product.save!
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'skippable', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(order.reload.order_items.count).to eq 1

      # If barcode not found
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(false)
      expect(result['error_messages']).to include("Barcode '1234' doesn't match any item on this order")
      
      # If Barcode found
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      order.reload
      expect(order.status).to eq("awaiting")


      # IF restart code enabled and equal to input
      @scanpacksetting.restart_code_enabled = true
      @scanpacksetting.restart_code = 'restart'
      @scanpacksetting.save!
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'restart', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['next_state']).to eq("scanpack.rfo")

      # IF service issue code enabled and equal to input
      @scanpacksetting.service_issue_code_enabled = true
      @scanpacksetting.service_issue_code = 'serviceissue'
      @scanpacksetting.save!
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'serviceissue', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['next_state']).to eq("scanpack.rfo")
      expect(result['data']['ask_note']).to eq(true)

      # IF service issue code enabled and equal to input but orders already scanned
      @scanpacksetting.service_issue_code_enabled = true
      @scanpacksetting.service_issue_code = 'serviceissue'
      @scanpacksetting.save!
      order.status = 'scanned'
      order.save!
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'serviceissue', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('Order with id: '+order.id.to_s+' is already in scanned state')
  end

  it "should scan product by barcode and order status should still be in awaiting status when there are unscanned items of the same product" do
      request.accept = "application/json"

      order = FactoryGirl.create(:order, :status=>'awaiting')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }


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
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', store: store)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1234567890', :id => order.id }

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

      order = FactoryGirl.create(:order, :status=>'awaiting')
      @user.role.update_attribute(:change_order_status, false)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      # If not in serviceissue
      post :scan_barcode, {:state=>'scanpack.rfp.confirmation.cos', :input => '1234567890', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include(
        "Only orders with status Service issue"\
        "can use change of status confirmation code"
      )

      # If cannot change order status
      order.update_attribute(:status, 'serviceissue')
      post :scan_barcode, {:state=>'scanpack.rfp.confirmation.cos', :input => '1234567890', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.cos")
      expect(order.status).to eq("serviceissue")
      expect(result['error_messages']).to include("User with confirmation code: 1234567890 does not have permission to change order status")

      # If can change order status
      @user.role.update_attribute(:change_order_status, true)
      post :scan_barcode, {:state=>'scanpack.rfp.confirmation.cos', :input => '1234567890', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfp.default")
      order.reload
      expect(order.status).to eq("awaiting")

    end

    # it "should not process confirmation code for change of order status since user does not have change order status" do
    #   request.accept = "application/json"
    #   order = FactoryGirl.create(:order, :status=>'serviceissue', store: Store.first)

    #   product = FactoryGirl.create(:product)
    #   product_sku = FactoryGirl.create(:product_sku, :product=> product)
    #   product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

    #   order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
    #                 :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

    #   post :scan_barcode, {:state=>'scanpack.rfp.confirmation.cos', :input => '1234567890', :id => order.id }


    #   expect(response.status).to eq(200)
    #   result = JSON.parse(response.body)
    #   expect(result["status"]).to eq(true)
    #   expect(result["data"]["next_state"]).to eq("scanpack.rfp.confirmation.cos")
    # end

    it "should not process confirmation code for change of order status since confirmation code does not exist" do
      request.accept = "application/json"

      order = FactoryGirl.create(:order, :status=>'serviceissue')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)


      post :scan_barcode, {:state=>'scanpack.rfp.confirmation.cos', :input => '123456789123', :id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result["data"]["next_state"]).to eq("scanpack.rfo")
      expect(result["error_messages"].first).to eq(
          "Could not find any user with confirmation code")
    end
  end

  describe "Product Kit Scan" do
    it "should scan single kits" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

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



      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'IPROTOBAR', :id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(0)
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

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
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product = FactoryGirl.create(:product, :name=>'PRODUCT1', :packing_placement=>40)
      product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'SKU1')
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
                        :kit_parsing=>'individual', :packing_placement=>50)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'IPROTO1',:packing_placement=>50, add_to_any_order: true)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      kit_product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)

      kit_product2 = FactoryGirl.create(:product, :name=>'IPROTO2', :packing_placement=>50)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['scanned_items'].length).to eq(1)
      expect(result['data']['order']['scanned_items'].first['name']).to eq('PRODUCT1')
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(2)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['scanned_items'].length).to eq(3)
      # expect(result['data']['order']['scanned_items'].last['name']).to eq('IPROTO1')
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['scanned_items'].length).to eq(4)
      # expect(result['data']['order']['scanned_items'].last['name']).to eq('iPhone Protection Kit')
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['scanned_items'].length).to eq(4)
      # expect(result['data']['order']['scanned_items'].last['name']).to eq('iPhone Protection Kit')
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO2')
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['qty_remaining']).to eq(1)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      # IF product barcode not found
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(0)
      expect(result['data']['order']['scanned_items'].length).to eq(4)
      # expect(result['data']['order']['scanned_items'].last['child_items'].length).to eq(2)
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')


      order_item.reload
      expect(order_item.scanned_status).to eq("scanned")
      expect(order_item.scanned_qty).to eq(1)

      order_item_kit.reload
      expect(order_item_kit.scanned_status).to eq("scanned")
      expect(order_item_kit.scanned_qty).to eq(2)

      order.reload
      expect(order.status).to eq("awaiting")
      expect(result['data']['order']['unscanned_items'].length).to eq(0)
      expect(result['data']['order']['scanned_items'].length).to eq(4)
      # order_item.reload
      # expect(order_item.scanned_qty).to eq(1)
      # expect(order_item.scanned_status).to eq("scanned")
    end

    it "should scan product by lot number and record serial number for kit" do
      request.accept = "application/json"
      @scanpacksetting.escape_string_enabled = true
      @scanpacksetting.record_lot_number = true
      @scanpacksetting.escape_string = ' .. '
      @scanpacksetting.save!

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
                        :kit_parsing=>'individual', :packing_placement=>50)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'IPROTO1',:packing_placement=>50, record_serial: true)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      kit_product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)

      kit_product2 = FactoryGirl.create(:product, :name=>'IPROTO2', :packing_placement=>50, record_serial: true)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)

      kit_product3 = FactoryGirl.create(:product, :name=>'IPROTO3', :packing_placement=>50, record_serial: true)
      kit_product3_sku = FactoryGirl.create(:product_sku, :product=> kit_product3, :sku=> 'IPROTO3')
      kit_product3_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product3, :barcode => 'KITITEM3')

      product_kit_sku3 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product3.id)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM1 .. ITEM1LOT', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(3)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(product_kit.product_lots.count).to eq(1)
      expect(product_kit.product_lots.pluck :lot_number).to include('ITEM1LOT')

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM2 .. ITEM2LOT', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(3)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(product_kit.product_lots.count).to eq(2)
      expect(product_kit.product_lots.pluck :lot_number).to include('ITEM2LOT')

      get :serial_scan, {barcode: 'KITITEM3', clicked: true, :order_id => order.id, product_id: product_kit.id, serial: 4}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(3)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('IPROTO1')
      expect(product_kit.product_lots.count).to eq(2)
      expect(product_kit.order_serial.pluck :serial).to include('4')
    end

    it "should scan product by lot number and record serial number for kit with single parsing" do
      request.accept = "application/json"
      @scanpacksetting.escape_string_enabled = true
      @scanpacksetting.record_lot_number = true
      @scanpacksetting.escape_string = ' .. '
      @scanpacksetting.save!

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
                        :kit_parsing=>'single', :packing_placement=>50, record_serial: true)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'IPROTO1',:packing_placement=>50, record_serial: true)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      kit_product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)

      kit_product2 = FactoryGirl.create(:product, :name=>'IPROTO2', :packing_placement=>50, record_serial: true)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)

      kit_product3 = FactoryGirl.create(:product, :name=>'IPROTO3', :packing_placement=>50, record_serial: true)
      kit_product3_sku = FactoryGirl.create(:product_sku, :product=> kit_product3, :sku=> 'IPROTO3')
      kit_product3_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product3, :barcode => 'KITITEM3')

      product_kit_sku3 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product3.id)

      get :serial_scan, {barcode: 'IPROTOBAR', clicked: true, :order_id => order.id, product_id: product_kit.id}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['data']['serial']['ask']).to eq true
      expect(result['data']['serial']['product_id']).to eq product_kit.id

      get :serial_scan, {barcode: 'IPROTOBAR', clicked: true, :order_id => order.id, product_id: product_kit.id, serial: 4}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(product_kit.order_serial.pluck :serial).to include('4')
    end

    it "should not scan product by serial number if barcode found or special code or user confirmation code or scanpacksetting action codes" do
      request.accept = "application/json"
      @scanpacksetting.escape_string_enabled = true
      @scanpacksetting.record_lot_number = true
      @scanpacksetting.escape_string = ' .. '
      @scanpacksetting.save!

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
                        :kit_parsing=>'individual', :packing_placement=>50)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'IPROTO1',:packing_placement=>50, record_serial: true)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      kit_product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)

      get :serial_scan, {barcode: 'KITITEM1', clicked: true, :order_id => order.id, product_id: product_kit.id, serial: 'KITITEM1'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include('Product Serial number: "KITITEM1" can not be the same as a confirmation code, one of the action codes or any product barcode')

      get :serial_scan, {barcode: 'KITITEM1', clicked: true, :order_id => order.id, product_id: product_kit.id, serial: 'SKIP'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include('Product Serial number: "SKIP" can not be the same as a confirmation code, one of the action codes or any product barcode')

      @user.confirmation_code = '123456'
      @user.save!
      get :serial_scan, {barcode: 'KITITEM1', clicked: true, :order_id => order.id, product_id: product_kit.id, serial: '123456'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include('Product Serial number: "123456" can not be the same as a confirmation code, one of the action codes or any product barcode')
    end

    it "should split and scan kits" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

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

      kit_product2 = FactoryGirl.create(:product, :name=>'Screen Wiper', :packing_placement=>40)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)

      kit_product3 = FactoryGirl.create(:product, :name=>'Instruction Manual', :packing_placement=>50)
      kit_product3_sku = FactoryGirl.create(:product_sku, :product=> kit_product3, :sku=> 'IPROTO3')
      kit_product3_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product3, :barcode => 'KITITEM3')

      product_kit_sku3 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product3.id)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
              :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)


      get :scan_barcode, { :state =>'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['unscanned_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['name']).to eq('iPhone Protection Kit')
      expect(result['data']['order']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, { :state =>'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, { :state =>'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('Protection Sheet')
      expect(result['data']['order']['unscanned_items'].last['product_type']).to eq('single')
      expect(result['data']['order']['unscanned_items'].last['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, { :state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')

      get :scan_barcode, { :state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('Screen Wiper')
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')


      get :scan_barcode, { :state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')

      get :scan_barcode, { :state => 'scanpack.rfp.default', :input => 'KITITEM3', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].length).to eq(1)
      expect(result['data']['order']['unscanned_items'].first['child_items'].first['name']).to eq('Instruction Manual')


      get :scan_barcode, { :state => 'scanpack.rfp.default', :input => 'KITITEM3', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(result['data']['order']['unscanned_items'].length).to eq(0)
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

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
      expect(result['data']['next_state']).to eq('scanpack.rfo')
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
      order2 = FactoryGirl.create(:order, :status=>'awaiting', increment_id: '432432')

      put :scan_barcode, {:state => 'scanpack.rfp.recording', :id => order.id, :input=>'1234567890' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      order.reload
      expect(order.status).to eq('scanned')

      #If already scanned
      put :scan_barcode, {:state => 'scanpack.rfp.recording', :id => order.id, :input=>'1234567890' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include("The order is not in awaiting state. Cannot scan the tracking number")
      
      #IF id nil
      put :scan_barcode, {:state => 'scanpack.rfp.recording', :id => nil, :input=>'1234567890' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include("Could not find order with id: "+ nil.to_s)

      #IF input blank
      put :scan_barcode, {:state => 'scanpack.rfp.recording', :id => order2.id, :input=>'' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['error_messages']).to include("No tracking number is provided")
    end

    # it "should scan orders with multiple kit products 1" do

    #   request.accept = "application/json"

    #   #create an order with one order item which is an individual product,
    #   #another is a kit which has a quantity of 2 and depedently splittable.
    #   order = FactoryGirl.create(:order, :status=>'awaiting')

    #   product = FactoryGirl.create(:product)
    #   product_sku = FactoryGirl.create(:product_sku, :product=> product)
    #   product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

    #   order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

    #   product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
    #                     :kit_parsing=>'depends')
    #   product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
    #   product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
    #   order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
    #                 :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

    #   kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
    #   kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
    #   kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

    #   product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
    #   order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus=> product_kit_sku)

    #   kit_product2 = FactoryGirl.create(:product)
    #   kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
    #   kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

    #   product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
    #   order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus => product_kit_sku2)

    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
    #            :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)

    #   #scanned barcode: BARCODE1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order,kit_product_barcode)
      
    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   1, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order,kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 1,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)
    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 1, 1, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   #expected_result['data']['next_item_present'] = true
    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call(expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   expected_result['data']['next_state'] ='scanpack.rfp.tracking'

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 0,
    #   2, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 0, 2, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)
    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 0, 2, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #order status
    #   order.reload
    #   expect(order.status).to eq('awaiting')
    # end

    # it "should scan orders with multiple kit products" do

    #   request.accept = "application/json"

    #   #create an order with one order item which is an individual product,
    #   #another is a kit which has a quantity of 2 and depedently splittable.
    #   order = FactoryGirl.create(:order, :status=>'awaiting')

    #   product = FactoryGirl.create(:product)
    #   product_sku = FactoryGirl.create(:product_sku, :product=> product)
    #   product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

    #   order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

    #   product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
    #                     :kit_parsing=>'depends')
    #   product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
    #   product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
    #   order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
    #                 :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

    #   kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
    #   kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
    #   kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

    #   product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
    #   order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus=> product_kit_sku)

    #   kit_product2 = FactoryGirl.create(:product)
    #   kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
    #   kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

    #   product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
    #   order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus => product_kit_sku2)

    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
    #            :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)

    #   #scanned barcode: BARCODE1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   1, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))


    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 1,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)
    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 1, 1, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   #expected_result['data']['next_item_present'] = true

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call(expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)

    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   expected_result['data']['next_state'] ='scanpack.rfp.tracking'

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product.name, [], 'IPROTO1', 0,
    #   2, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 0, 2, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)
    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 0, 2, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result['data']['order']['scanned_items']).to eq(JSON.parse(expected_result['data']['order']['scanned_items'].to_json))
    #   expect(result['data']['order']['unscanned_items']).to eq(JSON.parse(expected_result['data']['order']['unscanned_items'].to_json))


    #   #order status
    #   order.reload
    #   expect(order.status).to eq('awaiting')
    # end

    # it "should scan orders with multiple kit products and quantities" do

    #   request.accept = "application/json"

    #   #create an order with one order item which is an individual product,
    #   #another is a kit which has a quantity of 2 and depedently splittable.
    #   order = FactoryGirl.create(:order, :status=>'awaiting', store: Store.first)

    #   product = FactoryGirl.create(:product)
    #   product_sku = FactoryGirl.create(:product_sku, :product=> product)
    #   product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

    #   order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
    #                 :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

    #   product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
    #                     :kit_parsing=>'depends')
    #   product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
    #   product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
    #   order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
    #                 :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

    #   kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
    #   kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
    #   kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

    #   product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id, :qty=> 3)
    #   order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus=> product_kit_sku)

    #   kit_product2 = FactoryGirl.create(:product)
    #   kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
    #   kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

    #   product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id, :qty=> 4)
    #   order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
    #         :product_kit_skus => product_kit_sku2)

    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
    #            :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)

    #   #scanned barcode: BARCODE1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, product_barcode)

    #   unscanned_item = @unscanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 1, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 1, 1, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   #expected_result['data']['next_item_present'] = true
    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call(expected_result['data']['order']['unscanned_items'].first.clone)
    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: BARCODE1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, product_barcode)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 1, 0, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call(expected_result['data']['order']['unscanned_items'].first.clone)
    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 1, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call(expected_result['data']['order']['unscanned_items'].first.clone)

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3,
    #   1, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3,
    #   1, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 2, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2,
    #   2, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 3, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true


    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(1)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1,
    #   3, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1,
    #   3, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 4, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(1)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   # child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   # 3, 50, 50,
    #   # kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'single', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, nil,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   4, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 5, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)

    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3,
    #   5, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 3,
    #   5, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 6, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2,
    #   6, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 2,
    #   6, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 7, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))


    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1,
    #   7, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 1,
    #   7, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 8, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].last.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM2
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product2_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 6,
    #   0, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]
    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)
    #   expect(order_item_kit.kit_split_scanned_qty).to eq(0)
    #   expect(order_item_kit.scanned_qty).to eq(0)



    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 5,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 5,
    #   1, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 5, 1, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 4,
    #   2, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 4,
    #   2, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 2, 0, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 4, 2, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   3, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 3,
    #   3, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 3, 3, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2,
    #   4, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 2,
    #   4, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 2, 4, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   5, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   unscanned_item = @unscanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items,nil,false)

    #   expected_result['data']['order']['unscanned_items'] << unscanned_item


    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 1,
    #   5, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 1, 1, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 1, 5, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expected_result['data']['order']['next_item'] = @next_item_recommendation_l.call( expected_result['data']['order']['unscanned_items'].first['child_items'].first.clone)
    #   #expected_result['data']['next_item_present'] = true

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #scanned barcode: KITITEM1
    #   get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

    #   result = @get_response_l.call(response)

    #   expected_result = @expected_result_l.call(order, kit_product_barcode)

    #   order_item_kit.reload

    #   expect(order_item_kit.kit_split_qty).to eq(2)

    #   expected_result['data']['next_state'] = 'scanpack.rfp.tracking'

    #   scanned_item = @scanned_item_l.call('Apple iPhone 5S', 'single', [],
    #           'IPHONE5S', 0, 2, 50, product.product_barcodes,
    #           product.id, order_item.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   child_items = []

    #   child_items << @child_item_l.call('Apple iPhone 5C', [], 'IPROTO1', 0,
    #   6, 50, 50,
    #   kit_product.product_barcodes, kit_product.id, order_item_kit_product.id)

    #   child_items << @child_item_l.call(kit_product2.name, [], 'IPROTO2', 0,
    #   8, 50, 50,
    #   kit_product2.product_barcodes, kit_product2.id, order_item_kit_product2.id)

    #   scanned_item = @scanned_item_l.call('iPhone Protection Kit', 'individual', [],
    #           'IPROTO', 0, 2, 50, product_kit.product_barcodes,
    #           product_kit.id, order_item_kit.id, child_items)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product2.name, 'single', [],
    #           'IPROTO2', 0, 9, 50, kit_product2.product_barcodes,
    #           kit_product2.id, order_item2.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item

    #   scanned_item = @scanned_item_l.call(kit_product.name, 'single', [],
    #           'IPROTO1', 0, 6, 50, kit_product.product_barcodes,
    #           kit_product.id, order_item_kit.id, nil)

    #   expected_result['data']['order']['scanned_items'] << scanned_item
    #   expected_result['data']['order_complete'] =  true
    #   #expected_result['data']['most_recent_scanned_products'] = session[:most_recent_scanned_products]

    #   expect(result).to eq(JSON.parse(expected_result.to_json))

    #   #order status
    #   order.reload
    #   expect(order.status).to eq('awaiting')
    # end


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
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      #scanned barcode: BARCODE1
      get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

      get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_barcode, {:state => 'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

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
      expect(kit_product_inv_wh.sold_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      expect(kit_product2_inv_wh.sold_inv).to eq(2)
    end

    it "should scan orders with multiple kit products and adjust inventory accordingly when some kits are not split1" do
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
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      #scanned barcode: BARCODE1
      get :scan_barcode, {:state => 'scanpack.rfp.default', 
        :input => 'BARCODE1', :id => order.id }

      get :scan_barcode, {:state => 'scanpack.rfp.default', 
        :input => 'KITITEM1', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      get :scan_barcode, {:state => 'scanpack.rfp.default', 
        :input => 'KITITEM2', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_barcode, {:state => 'scanpack.rfp.default', 
        :input => 'IPROTOBAR', :id => order.id }

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
      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)
      expect(product_kit_inv_wh.sold_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
      expect(kit_product_inv_wh.sold_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      expect(kit_product2_inv_wh.sold_inv).to eq(2)
    end

    it "should scan orders with multiple kit products and adjust inventory accordingly when some kits are not split also should reset order scan and adjust inventory accordingly" do
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
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      #scanned barcode: BARCODE1
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM1', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'KITITEM2', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'IPROTOBAR', :id => order.id }

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
      put :reset_order_scan, {:order_id => order.id}

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)
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
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)

      #scanned barcode: BARCODE1
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'BARCODE1', :id => order.id }

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'IPROTOBAR', :id => order.id }

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(2)


      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'IPROTOBAR', :id => order.id }

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

      product_kit_inv_wh.reload
      expect(product_kit_inv_wh.available_inv).to eq(25)
      expect(product_kit_inv_wh.allocated_inv).to eq(0)
      expect(product_kit_inv_wh.sold_inv).to eq(0)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(23)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
      expect(kit_product_inv_wh.sold_inv).to eq(2)

      kit_product2_inv_wh.reload
      expect(kit_product2_inv_wh.available_inv).to eq(23)
      expect(kit_product2_inv_wh.allocated_inv).to eq(0)
      expect(kit_product2_inv_wh.sold_inv).to eq(2)

    end

  end
end

