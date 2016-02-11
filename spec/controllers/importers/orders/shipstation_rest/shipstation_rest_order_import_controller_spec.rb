require 'rails_helper'

describe OrdersController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user_role = FactoryGirl.create(:role,:name=>'shipstation_rest_spec_tester_role', :add_edit_stores => true, :add_edit_order_items => true, :import_orders => true, :change_order_status => true, :change_order_status => true, :delete_products => true, :import_products => true, :add_edit_products=>true)
    @user = FactoryGirl.create(:user,:name=>'Shipstation API 2 Tester', :username=>"shipstation_rest_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'shipstation_rest_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'shipstation_rest_store', :store_type=>'Shipstation API 2', :inventory_warehouse=>@inv_wh, :status => true)
    @credential = FactoryGirl.create(:shipstation_rest_credential, :store_id=>@store.id, 
																																	 :api_key => "test", 
																																	 :api_secret => "test",
																																	 :shall_import_awaiting_shipment => true, 
																																	 :last_imported_at => Time.now-30.minutes,
																																	 :shall_import_shipped => true, 
																																	 :warehouse_location_update => false, 
																																	 :shall_import_customer_notes => false, 
																																	 :shall_import_internal_notes => false, 
																																	 :regular_import_range => 3, 
																																	 :gen_barcode_from_sku => true, 
																																	 :shall_import_pending_fulfillment => true)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "GET 'import_all'" do    
		it "Import from Shipstation should fail for 'Shipstation API 2' store type" do
			request.accept = "application/json"
			get :import_all, {}
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to eq("failed")
			expect(import_item.import_type).to eq("regular")
		end
  end
  
  describe "GET 'import_all'" do    
		it "Import from Shipstation should import orders for 'Shipstation API 2' store type" do
			@credential.update_attributes(:api_key => ENV['SHIPSTATION_REST_API_KEY'], :api_secret => ENV['SHIPSTATION_REST_API_SECRET'])
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
			expect(import_item.import_type).to eq("regular")
		end
  end
  
  describe "GET 'import'" do    
		it "Should run import for Single store - Shipstation API 2 and should complete successfully" do
			@credential.update_attributes(:api_key => ENV['SHIPSTATION_REST_API_KEY'], :api_secret => ENV['SHIPSTATION_REST_API_SECRET'])
			request.accept = "application/json"
			get :import, { :store_id=>@store.id, :import_type=> 'quick' }
			expect(response.status).to eq(200)
			result = JSON.parse(response.body)
			expect(result["status"]).to eq(true)
			order_import_summary = OrderImportSummary.last
			import_items = order_import_summary.import_items
			expect(import_items.count).to eq(1)
			import_item = import_items.first
			expect(import_item.status).to_not be("completed")
			expect(import_item.import_type).to eq("quick")
		end
  
  end
  
end
