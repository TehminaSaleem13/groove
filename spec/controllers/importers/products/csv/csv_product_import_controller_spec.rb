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
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh, :status => true)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "POST 'product import'" do
    it "imports products from csv file with import option 1" do
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_option1"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(34)
    end
    it "imports products from csv file with import option 2 without existing products" do
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_option2"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(0)
    end
    it "imports products from csv file with import option 2 with already existing products" do
      # import orders
      request.accept = "application/json"
      get :csv_import_data, {:type => 'order', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"YYYY/MM/DD TIME", :day_month_sequence=>"MM/DD", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      import_item = ImportItem.find_by_store_id(@store.id)
      expect(import_item.status).to eq('completed')
      expect(Order.all.count).to eq(9)
      expect(Product.all.count).to eq(21)
      # import products with option 2
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_option2"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(21)
    end
    it "imports products from csv file with import option 3" do
      # import orders
      request.accept = "application/json"
      get :csv_import_data, {:type => 'order', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"YYYY/MM/DD TIME", :day_month_sequence=>"MM/DD", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      import_item = ImportItem.find_by_store_id(@store.id)
      expect(import_item.status).to eq('completed')
      expect(Order.all.count).to eq(9)
      expect(Product.all.count).to eq(21)
      # import products with option 2
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_option3"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(41)
    end

    it "imports receiving instructions for products from csv file" do
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_rec_ins_map"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(34)
      expect(ProductSku.where(sku: 'K.IS.M').first.product.product_receiving_instructions).to eq("Thank-you!!!")
    end

    it "Delete a product during csv product import if the product name matches `[DELETE]`" do
      # import orders
      request.accept = "application/json"
      get :csv_import_data, {:type => 'order', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"YYYY/MM/DD TIME", :day_month_sequence=>"MM/DD", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      import_item = ImportItem.find_by_store_id(@store.id)
      expect(import_item.status).to eq('completed')
      expect(Order.all.count).to eq(9)
      expect(Product.all.count).to eq(21)
      product_id=ProductSku.where(:sku=>"R.S-CS.OFF").first.product.id
      # import products with option 2
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04_delete.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_option2"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(20)
      expect(Product.where(:id=>product_id).size).to eq(0)
    end

    it "If the product name in any record in the csv is blank, then existing product name should remain unchanged" do
      # import orders
      request.accept = "application/json"
      get :csv_import_data, {:type => 'order', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"YYYY/MM/DD TIME", :day_month_sequence=>"MM/DD", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      import_item = ImportItem.find_by_store_id(@store.id)
      expect(import_item.status).to eq('completed')
      expect(Order.all.count).to eq(9)
      expect(Product.all.count).to eq(21)
      # import products with option 2
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)
      products_names = Product.all.map(&:name)
      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04_name_blank.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_name_blank"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      expect(Product.all.count).to eq(21)
      expect(Product.all.map(&:name)).to match_array(products_names)
    end


    it "If the product name in any record in the csv is blank, then existing product name should remain unchanged" do
      # import orders
      request.accept = "application/json"
      get :csv_import_data, {:type => 'order', :id => @store.id}
      expect(response.status).to eq(200)

      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"YYYY/MM/DD TIME", :day_month_sequence=>"MM/DD", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
      expect(response.status).to eq(200)
      import_item = ImportItem.find_by_store_id(@store.id)
      expect(import_item.status).to eq('completed')
      expect(Order.all.count).to eq(9)
      expect(Product.all.count).to eq(21)
      # import products with option 2
      request.accept = "application/json"
      get :csv_import_data, {:type => 'product', :id => @store.id}
      expect(response.status).to eq(200)
      products_names = Product.all.map(&:name)
      request.accept = "application/json"
      get :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_04_barcode_blank.csv'))}
      expect(response.status).to eq(200)
      product = Product.includes(:product_skus).where("product_skus.sku = 'R.S'").first
      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_04_map_barcode_blank"))
      doc = eval(doc)
      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}
      
      expect(response.status).to eq(200)
      updated_product = Product.includes(:product_skus).where("product_skus.sku = 'R.S'").first
      expect(product.name).to_not eq(updated_product.name)
      expect(product.weight).to_not eq(updated_product.weight)
    end
  end
end
