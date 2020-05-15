require 'rails_helper'

RSpec.describe StoresController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryGirl.create(:role,:name=>'csv_spec_tester_role', :add_edit_stores => true, :import_products => true)
    @user = FactoryGirl.create(:user,:name=>'CSV Tester', :username=>"csv_spec_tester", :role => user_role)
    access_restriction = FactoryGirl.create(:access_restriction)
    inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>inv_wh, :status => true)
    csv_mapping = FactoryGirl.create(:csv_mapping, :store_id=>@store.id)
    @product = FactoryGirl.create(:product, :store_id=>@store.id)
    product_sku = FactoryGirl.create(:product_sku, :sku=>'BEFORE_SKU', :product_id=>@product.id)
  end

  describe "CSV Import" do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']
    end

    it "Remove Existing SKU and add new" do
      existing_product_sku = @product.product_skus.first.sku

      request.accept = "application/json"
      post :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_map_option3"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
      expect(@product.product_skus.first.sku).not_to eql(existing_product_sku)
    end

    it "Remove Existing SKU if multiple skus present" do
      product_sku = FactoryGirl.create(:product_sku, :sku=>'BEFORE_SKU1', :product_id=>@product.id)
      expect(@product.product_skus.count).to eq(2)

      request.accept = "application/json"
      post :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_map_option3_1"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
    end

    it "Do not remove SKU if only one skus is present" do
      existing_product_sku = @product.product_skus.first.sku
      expect(@product.product_skus.count).to eq(1)

      request.accept = "application/json"
      post :create_update_store, {:store_type => 'CSV', :status=> @store.status, :name => @store.name, :inventory_warehouse_id => @store.inventory_warehouse_id, :id => @store.id, :productfile => fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv'))}
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join("spec/fixtures/files/MT_Products_map_option3_1"))
      doc = eval(doc)

      request.accept = "application/json"
      post :csv_do_import, {:id => @store.id, :rows=>"2", :sep=>",", :other_sep=>"0", :delimiter=>"\"", :fix_width=>"0", :fixed_width=>"4", :contains_unique_order_items=>false, :generate_barcode_from_sku=>false, :use_sku_as_product_name=>false, :import_action=>doc[:map][:import_action], :map=>doc[:map][:map], :controller=>"stores", :action=>"csv_do_import", :store_id=> @store.id, :name=>doc[:name], :type=>'product', :flag=>'file_upload'}

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
      expect(@product.product_skus.first.sku).to eql(existing_product_sku)
    end
  end
end
