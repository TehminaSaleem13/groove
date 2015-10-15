require 'rails_helper'

describe StoresController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user_role = FactoryGirl.create(:role,:name=>'csv_spec_tester_role', :add_edit_stores => true, :import_products => true)
    @user = FactoryGirl.create(:user,:name=>'CSV Tester', :username=>"csv_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh, :status=>true)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "POST 'kit import'" do
    it "imports kit products from csv file" do
      request.accept = "application/json"
      get :csv_import_data, {:type => 'kit', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :kitfile => fixture_file_upload(Rails.root.join('/files/MT_Kits_03.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Kits_03_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'kit', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(17)
      expect(Product.where(:is_kit=>true).size).to eq(6)
      expect(Product.where(:is_kit=>false).size).to eq(11)
    end
  end
end
