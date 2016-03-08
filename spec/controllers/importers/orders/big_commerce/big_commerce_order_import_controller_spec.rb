require 'rails_helper'

describe OrdersController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user_role = FactoryGirl.create(:role,:name=>'big_commerce_spec_tester_role', :add_edit_stores => true, :add_edit_order_items => true, :import_orders => true, :change_order_status => true, :change_order_status => true, :delete_products => true, :import_products => true, :add_edit_products=>true)
    @user = FactoryGirl.create(:user,:name=>'BigCommerce Tester', :username=>"big_commerce_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'big_commerce_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'big_commerce_store', :store_type=>'big_commerce', :inventory_warehouse=>@inv_wh, :status => true)
    @credential = FactoryGirl.create(:big_commerce_credential, :store_id=>@store.id)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  # describe "GET 'import_all'" do    
		# it "Import from BigCommerce should fail because of access deny" do
		# 	request.accept = "application/json"
		# 	get :import_all, {}
		# 	expect(response.status).to eq(200)
		# 	result = JSON.parse(response.body)
		# 	expect(result["status"]).to eq(true)
			
		# 	order_import_summary = OrderImportSummary.last
		# 	import_items = order_import_summary.import_items
		# 	expect(import_items.count).to eq(1)
		# 	import_item = import_items.first
		# 	expect(import_item.status).to_not be("completed")
		# 	expect(import_item.import_type).to eq("regular")
		# end
  # end
  
  # describe "GET 'import'" do    
		# it "Should run import for Single store - BigCommerce and should fail because of access deny" do
		# 	request.accept = "application/json"
		# 	get :import, { :store_id=>@store.id, :days=>10, :import_type=> 'deep' }
		# 	expect(response.status).to eq(200)
		# 	result = JSON.parse(response.body)
		# 	expect(result["status"]).to eq(true)
			
		# 	order_import_summary = OrderImportSummary.last
		# 	import_items = order_import_summary.import_items
		# 	expect(import_items.count).to eq(1)
		# 	import_item = import_items.first
		# 	expect(import_item.status).to_not be("completed")
		# 	expect(import_item.import_type).to eq("deep")
		# end

  # end
  
end
