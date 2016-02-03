require 'rails_helper'

describe OrdersController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user_role = FactoryGirl.create(:role,:name=>'shipping_easy_spec_tester_role', :add_edit_stores => true, :add_edit_order_items => true, :import_orders => true, :change_order_status => true, :change_order_status => true, :delete_products => true, :import_products => true, :add_edit_products=>true)
    @user = FactoryGirl.create(:user,:name=>'ShippingEasy Tester', :username=>"shipping_easy_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipping_easy_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'shipping_easy_store', :store_type=>'ShippingEasy', :inventory_warehouse=>@inv_wh, :status => true)
    @credential = FactoryGirl.create(:shipping_easy_credential, :store_id=>@store.id, :api_key=>'xxxxxxxxxxxxxxxx', :api_secret=>'yyyyyyyyyyyyyyyyyyyyyyyyyyy', :import_ready_for_shipment => true, :import_shipped => true, :gen_barcode_from_sku => true)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "GET 'import_all'" do    
		it "Import from ShippingEasy should fail because of access deny" do
			request.accept = "application/json"
			get :import_all, {}
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			expect(result["status"]).to eq(true)
			
			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to eq("failed")
			expect(import_item.message).to eq("Access denied.")
			expect(import_item.import_type).to eq("regular")
		end
		
		it "Import from ShippingEasy should complete successfully" do
			@credential.update_attributes(:api_key=>'5c587aaaba338f34c99e0b9837f24ede', :api_secret=>'699e8f73a53774d36eb687e316b7327dc137f70beabcaa1e00d7ce4e9197fb96')
			request.accept = "application/json"
			get :import_all, {}
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			expect(result["status"]).to eq(true)

			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to eq("completed")
			expect(import_item.message).to be_blank
			expect(import_item.import_type).to eq("regular")
		end
  end
  
  describe "GET 'import'" do    
		it "Should run import for Single store - ShippingEasy and should fail because of access deny" do
			request.accept = "application/json"
			get :import, { :store_id=>@store.id, :days=>10, :import_type=> 'deep' }
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			expect(result["status"]).to eq(true)
			
			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to eq("failed")
			expect(import_item.message).to eq("Access denied.")
			expect(import_item.import_type).to eq("deep")
		end
		
		it "Should run import for Single store - ShippingEasy and should complete successfully" do
			@credential.update_attributes(:api_key=>'5c587aaaba338f34c99e0b9837f24ede', :api_secret=>'699e8f73a53774d36eb687e316b7327dc137f70beabcaa1e00d7ce4e9197fb96')
			request.accept = "application/json"
			get :import, { :store_id=>@store.id, :days=>10, :import_type=> 'deep' }
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			expect(result["status"]).to eq(true)

			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to eq("completed")
			expect(import_item.message).to be_blank
			expect(import_item.import_type).to eq("deep")
		end
  end
  
end
