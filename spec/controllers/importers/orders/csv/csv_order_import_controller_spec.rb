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
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end

  describe "POST 'order import'" do
    describe "non-unique items" do
      it "import non-unique items for a csv store" do
        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(9)
        expect(Product.all.count).to eq(21)
      end
      it "import non-unique items for a csv and applies intangibleness during import" do
        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "R.INTANGIBLE.SEA"
        scanpacksetting.save

        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
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

        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(9)
        expect(Product.all.count).to eq(21)
        expect(Product.where(:is_intangible=>true).size).to eq(2)
      end
      describe "Generate Barcode From SKU" do
        it "Products will be imported for each order item of each order with Barcode value same as SKU" do
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)

          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
          expect(response.status).to eq(200)

          doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
          doc = eval(doc)

          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(9)
          expect(Product.all.count).to eq(21)
          Product.all.each do |product|
            expect(product.status).to eq('active')
          end
          Order.all.each do |order|
            expect(order.status).to eq('awaiting')
          end
        end
      end
      describe "Use SKU as Product Name" do
        it "imports products with product names same as SKU" do
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)

          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/MT_Orders_04.csv'))}
          expect(response.status).to eq(200)

          doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Orders_04_map"))
          doc = eval(doc)

          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>true, :order_date_time_format=>"MM/DD/YY TIME", :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(9)
          expect(Product.all.count).to eq(21)
          Product.all.each do |product|
            expect(product.name).to eq(product.primary_sku)
          end
        end
      end
    end

    describe "unique items" do
      it "import unique items for a csv store" do
        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
        Product.all.each do |product|
          expect(product.status).to eq('new')
        end
        Order.all.each do |order|
          expect(order.status).to eq('onhold')
        end
      end
      it "import unique items for a csv store and applies intangibleness during import" do
        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "P-105"
        scanpacksetting.save

        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
        expect(Product.where(:is_intangible=>true).size).to eq(2)
      end
      it "import unique items for a csv store and applies intangibleness to multiple products during import" do
        scanpacksetting = ScanPackSetting.first
        scanpacksetting.intangible_setting_enabled = true
        scanpacksetting.intangible_string = "P-105,P-108"
        scanpacksetting.save

        request.accept = "application/json"
        get :csv_import_data, {:type => 'order', :id => @store.id}
        expect(response.status).to eq(200)

        request.accept = "application/json"
        get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
        expect(response.status).to eq(200)

        doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
        doc = eval(doc)

        request.accept = "application/json"
        post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
        expect(response.status).to eq(200)
        expect(Order.all.count).to eq(4)
        expect(Product.all.count).to eq(13)
        expect(Product.where(:is_intangible=>true).size).to eq(3)
      end
      describe "Generate Barcode From SKU" do
        it "Products will be imported for each order item of each order with Barcode value same as SKU" do
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)

          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)

          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)

          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(4)
          expect(Product.all.count).to eq(13)
          products = Product.where(Product.arel_table[:base_sku].not_eq(nil))
          products.each do |product|
            expect(product.primary_barcode).to eq(product.primary_sku)
          end
        end
        it "Products which have active base product become active products" do
          # import the products first
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)
          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)
          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)
          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(4)
          expect(Product.all.count).to eq(13)

          # delete all products except the base products
          products = Product.where(Product.arel_table[:base_sku].not_eq(nil))
          bulk_actions = Groovepacker::Products::BulkActions.new
          groove_bulk_actions = GrooveBulkActions.new
          groove_bulk_actions.identifier = 'product'
          groove_bulk_actions.activity = 'delete'
          groove_bulk_actions.save
          params = {:productArray=>products}
          current_tenant = Apartment::Tenant.current
          bulk_actions.delete(current_tenant, params, groove_bulk_actions.id, @user.name)
          expect(Product.all.count).to eq(5)

          #make the base products active
          products = Product.all
          products.each do |product|
            if product.product_barcodes.first.nil?
              sku = product.product_skus.first
              unless sku.nil?
                barcode = product.product_barcodes.new
                barcode.barcode = sku.sku
              end
            end
            product.update_product_status
          end
          products = Product.all
          products.each do |product|
            expect(product.status).to eq('active')
          end

          #now import ordes from csv by switching on generate barcode from sku.
          Order.destroy_all
          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)
          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)
          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Product.all.count).to eq(13)
          Product.all.each do |product|
            expect(product.status).to eq('active')
          end
          Order.all.each do |order|
            expect(order.status).to eq('awaiting')
          end
        end
        it "Products which have new/inactive base product stay as new products" do
          # import the products first
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)
          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)
          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)
          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(4)
          expect(Product.all.count).to eq(13)

          # delete all products except the base products
          products = Product.where(Product.arel_table[:base_sku].not_eq(nil))
          bulk_actions = Groovepacker::Products::BulkActions.new
          groove_bulk_actions = GrooveBulkActions.new
          groove_bulk_actions.identifier = 'product'
          groove_bulk_actions.activity = 'delete'
          groove_bulk_actions.save
          params = {:productArray=>products}
          current_tenant = Apartment::Tenant.current
          bulk_actions.delete(current_tenant, params, groove_bulk_actions.id, @user.name)
          expect(Product.all.count).to eq(5)

          #now import ordes from csv by switching on generate barcode from sku.
          Order.destroy_all
          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)
          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)
          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>true, :use_sku_as_product_name=>false, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Product.all.count).to eq(13)
          Product.all.each do |product|
            expect(product.status).to eq('new')
          end
          Order.all.each do |order|
            expect(order.status).to eq('onhold')
          end
        end
      end
      describe "Use SKU as Product Name" do
        it "imports products with product names same as SKU" do
          request.accept = "application/json"
          get :csv_import_data, {:type => 'order', :id => @store.id}
          expect(response.status).to eq(200)

          request.accept = "application/json"
          get :create_update_store, {:store_type => 'CSV', :id => @store.id, :orderfile => fixture_file_upload(Rails.root.join('/files/Order_Import_Test.csv'))}
          expect(response.status).to eq(200)

          doc = IO.read(Rails.root.join("spec/fixtures/files/Unique_Orders_map"))
          doc = eval(doc)

          request.accept = "application/json"
          post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :import_action=>nil, :contains_unique_order_items=>true, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>true, :order_date_time_format=>doc[:map][:order_date_time_format], :day_month_sequence=>"DD/MM", :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'order', :flag=>'file_upload'}
          expect(response.status).to eq(200)
          expect(Order.all.count).to eq(4)
          expect(Product.all.count).to eq(13)
          products = Product.where(Product.arel_table[:base_sku].not_eq(nil))
          products.each do |product|
            expect(product.name).to eq(product.base_sku)
          end
        end
      end
    end
  end
end
