require 'rails_helper'

describe StoreSettingsController do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user_role = FactoryGirl.create(:role,:name=>'csv_spec_tester_role', :add_edit_stores => true, :import_products => true)
    @user = FactoryGirl.create(:user,:name=>'CSV Tester', :username=>"csv_spec_tester", :role => @user_role)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "POST 'order import'" do
    describe "non-unique items" do
      it "import non-unique items for a csv store" do
        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)
        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(9)
        expect(Product.all.count).to eq(21)
      end
      it "import non-unique items for a csv and applies intangibleness during import" do
        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "R.INTANGIBLE.SEA"
        scanpacksetting.save

        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)
        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(9)
        expect(Product.all.count).to eq(21)
        expect(Product.where(:is_intangible=>true).size).to eq(1)
      end
      it "import non-unique items for a csv and applies intangibleness for multiple products during import" do
        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "R.INTANGIBLE.SEA,R.INTANGIBLE.SW"
        scanpacksetting.save

        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)
        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(9)
        expect(Product.all.count).to eq(21)
        expect(Product.where(:is_intangible=>true).size).to eq(2)
      end
    end

    describe "unique items" do
      it "import unique items for a csv store" do
        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)
        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
      end
      it "import unique items for a csv store and applies intangibleness during import" do
        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)

        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "P-105"
        scanpacksetting.save

        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
        expect(Product.where(:is_intangible=>true).size).to eq(2)
      end
      it "import unique items for a csv store and applies intangibleness to multiple products during import" do
        @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
        @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)

        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "P-105,P-108"
        scanpacksetting.save

        expect(Order.all.count).to eq(0)
        expect(Product.all.count).to eq(0)
        request.accept = "application/json"
        get :csvImportData, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :createUpdateStore, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csvDoImport, {:rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"store_settings", :action=>"csvDoImport", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
        expect(Product.where(:is_intangible=>true).size).to eq(3)
      end
    end
  end
end
