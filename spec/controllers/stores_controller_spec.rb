# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StoresController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true, add_edit_order_items: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryBot.create(:access_restriction)
    @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: @inv_wh, status: true)
    csv_mapping = FactoryBot.create(:csv_mapping, store_id: @store.id)
  end

  describe 'CSV Import' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Import CSV Products' do
      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, productfile: fixture_file_upload(Rails.root.join('/files/csv_product_import.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join('spec/fixtures/files/csv_product_import_map'))
      doc = eval(doc)

      request.accept = 'application/json'
      post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'product', flag: 'file_upload', encoding_format: 'UTF-8' }

      expect(response.status).to eq(200)
      expect(Product.count).to eq(5)
      expect(ProductBarcode.count).to eq(15)
      expect(ProductSku.count).to eq(5)
    end

    it 'Import Kit Products' do
      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, kitfile: fixture_file_upload(Rails.root.join('/files/csv_kit_import.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join('spec/fixtures/files/csv_kit_import_map'))
      doc = eval(doc)

      request.accept = 'application/json'
      post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'kit', flag: 'file_upload' }

      expect(response.status).to eq(200)
      expect(Product.count).to eq(7)
      expect(Product.where(is_kit: 1).count).to eq(3)
    end
  end

  describe 'CSV Test and Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
      @product = FactoryBot.create(:product, store_id: @store.id)
      product_sku = FactoryBot.create(:product_sku, sku: 'BEFORE_SKU', product_id: @product.id)
    end

    it 'Remove Existing SKU and add new' do
      existing_product_sku = @product.product_skus.first.sku

      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, productfile: fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join('spec/fixtures/files/MT_Products_map_option3'))
      doc = eval(doc)

      request.accept = 'application/json'
      post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'product', flag: 'file_upload', encoding_format: 'UTF-8' }

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
      expect(@product.product_skus.first.sku).not_to eql(existing_product_sku)
    end

    # it 'Import CSV Products Foreign/Chinese Characters Support' do
    #   request.accept = 'application/json'
    #   post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, productfile: fixture_file_upload(Rails.root.join('/files/csv_product_import.csv')) }
    #   expect(response.status).to eq(200)

    #   doc = IO.read(file_fixture('csv_product_import_map'))
    #   doc = eval(doc)

    #   request.accept = 'application/json'
    #   post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'product', flag: 'file_upload', encoding_format: 'UTF-8' }
    #   expect(response.status).to eq(200)
    #   expect(Product.count).to eq(6)
    #   expect(Product.last.name.length).to eq(11)
    #   expect(ProductBarcode.count).to eq(15)
    #   expect(ProductSku.count).to eq(6)
    # end

    it 'Remove Existing SKU if multiple skus present' do
      product_sku = FactoryBot.create(:product_sku, sku: 'BEFORE_SKU1', product_id: @product.id)
      expect(@product.product_skus.count).to eq(2)

      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, productfile: fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join('spec/fixtures/files/MT_Products_map_option3_1'))
      doc = eval(doc)

      request.accept = 'application/json'
      post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'product', flag: 'file_upload', encoding_format: 'UTF-8' }

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
    end

    it 'Do not remove SKU if only one skus is present' do
      existing_product_sku = @product.product_skus.first.sku
      expect(@product.product_skus.count).to eq(1)

      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, productfile: fixture_file_upload(Rails.root.join('/files/MT_Products_remove_sku.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(Rails.root.join('spec/fixtures/files/MT_Products_map_option3_1'))
      doc = eval(doc)

      request.accept = 'application/json'
      post :csv_do_import, params: { id: @store.id, rows: '2', sep: ',', other_sep: '0', delimiter: '"', fix_width: '0', fixed_width: '4', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, import_action: doc[:map][:import_action], map: doc[:map][:map], controller: 'stores', action: 'csv_do_import', store_id: @store.id, name: doc[:name], type: 'product', flag: 'file_upload' }

      expect(response.status).to eq(200)
      expect(@product.product_skus.count).to eq(1)
      expect(@product.product_skus.first.sku).to eql(existing_product_sku)
    end

    it 'Import via FTP' do
      store = Store.where(store_type: 'CSV', status: true).first
      FtpCredential.create(store_id: store.id, host:"ecomdash-ftp.cloudapp.net/Inventory", username: "DeJaViewedLLC", password: "DeJaViewedLLC123!", connection_method: "ftp")
      request.accept = 'application/json'

      groove_ftp = FTP::FtpConnectionManager.get_instance(store)
      ftp = groove_ftp.delete_older_files
      expect(response.status).to eq(200)
    end

    it 'Import via FTP without host' do
      store = Store.where(store_type: 'CSV', status: true).first
      FtpCredential.create(store_id: store.id, host:"ecomdash-ftp.cloudapp.net", username: nil, password: "DeJaViewedLLC123!", connection_method: "ftp")
      request.accept = 'application/json'

      groove_ftp = FTP::FtpConnectionManager.get_instance(store)
      ftp = groove_ftp.delete_older_files
      expect(response.status).to eq(200)
    end

    it 'Import via SFTP' do
      store = Store.where(store_type: 'CSV', status: true).first
      FtpCredential.create(store_id: store.id, host:"34.202.114.73/groovepacker", username: "groovepacker", password: "grOOvePacKeRRG!!", connection_method: "sftp")
      request.accept = 'application/json'

      groove_ftp = FTP::FtpConnectionManager.get_instance(store)
      sftp = groove_ftp.delete_older_files
      expect(response.status).to eq(200)
    end

    it 'Import Via SFTP without Username' do
      store = Store.where(store_type: 'CSV', status:true).first
      FtpCredential.create(store_id: store.id, host:"34.202.114.73/groovepacker", username: nil, password: "grOOvePacKeRRG!!", connection_method: "sftp")
      request.accept = 'application/json'

      groove_ftp = FTP::FtpConnectionManager.get_instance(store)
      sftp = groove_ftp.delete_older_files
      expect(response.status).to eq(200)
    end
  end

  describe 'ShippingEasy Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      se_store = Store.create(name: 'ShippingEasy', status: true, store_type: 'ShippingEasy', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true)
      se_store_credentials = ShippingEasyCredential.create(store_id: se_store.id, api_key: 'apikeyapikeyapikeyapikeyapikeyse', api_secret: 'apisecretapisecretapisecretapisecretapisecretapisecretapisecrets', import_ready_for_shipment: false, import_shipped: true, gen_barcode_from_sku: false, popup_shipping_label: false, ready_to_ship: true, import_upc: true, allow_duplicate_id: true)
    end

    it 'Import SE Single Order' do
      allow_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:get_single_order).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/SE_test_single_order.yaml'))))

      request.accept = 'application/json'

      se_store = Store.where(store_type: 'ShippingEasy').last

      get :get_order_details, params: { order_no: 'SE_QFRANGE3', store_id: se_store.id }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
    end

    it 'Import SE On Demand Order Import' do
      allow_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:get_single_order).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/se_same_sku_test.yaml'))))
      request.accept = 'application/json'

      se_store = Store.where(store_type: 'ShippingEasy').last
      se_credentials = se_store.shipping_easy_credential
      se_credentials.multiple_lines_per_sku_accepted = true
      se_credentials.save

      get :get_order_details, params: { order_no: '105908', store_id: se_store.id }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
    end

    it 'show error if required field not mapped' do
      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, orderfile: fixture_file_upload(Rails.root.join('/files/Order_import_fail.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(file_fixture('Order_check_file_map_1'))
      doc = eval(doc)

      request.accept = 'application/json'

      post :csv_check_data, params: { id: @store.id, map: doc[:map], controller: 'stores', action: 'csv_check_data', store_id: @store.id, rows: 2, sep: ',', other_sep: 0, delimiter: '"', fix_width: 0, fixed_width: 4, import_action: 'update_order', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, order_date_time_format: 'Default', day_month_sequence: 'MM/DD', encoding_format: 'ASCII + UTF-8', type: 'order', name: 'Order_check_file_map_1', flag: 'file_upload', order_placed_at: '2020-05-25T11:37:36.352Z' }
      expect(response.status).to eq(200)
      expect((eval response.body)[:status]).to eq(false)
    end

    it 'no error if file check passed' do
      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'CSV', status: @store.status, name: @store.name, inventory_warehouse_id: @store.inventory_warehouse_id, id: @store.id, orderfile: fixture_file_upload(Rails.root.join('/files/Order_import_pass.csv')) }
      expect(response.status).to eq(200)

      doc = IO.read(file_fixture('Order_check_file_map_1'))
      doc = eval(doc)

      request.accept = 'application/json'

      post :csv_check_data, params: { id: @store.id, map: doc[:map], controller: 'stores', action: 'csv_check_data', store_id: @store.id, rows: 2, sep: ',', other_sep: 0, delimiter: '"', fix_width: 0, fixed_width: 4, import_action: 'update_order', contains_unique_order_items: false, generate_barcode_from_sku: false, use_sku_as_product_name: false, order_date_time_format: 'Default', day_month_sequence: 'MM/DD', encoding_format: 'ASCII + UTF-8', type: 'order', name: 'Order_check_file_map_1', flag: 'file_upload', order_placed_at: '2020-05-25T11:37:36.352Z' }
      expect(response.status).to eq(200)
      expect((eval response.body)[:status]).to eq(true)
    end

    it 'Update SE Store Settings' do
      request.accept = 'application/json'
      se_store = Store.where(store_type: 'ShippingEasy').last

      post :create_update_store, params: { 'file_path' => '', 'inventory_warehouse_id' => '1', 'is_fba' => 'false', 'product_ftp_import' => 'false', 'id' => se_store.id, 'name' => 'Shipping Easy', 'status' => 'false', 'store_type' => 'ShippingEasy', 'order_date' => 'null', 'created_at' => '2020-04-28T08:52:12.000Z', 'updated_at' => '2021-07-22T11:34:44.000Z', 'thank_you_message_to_customer' => 'null', 'auto_update_products' => 'true', 'update_inv' => 'true', 'on_demand_import' => 'true', 'fba_import' => 'false', 'csv_beta' => 'true', 'is_verify_separately' => 'null', 'split_order' => 'shipment_handling_v2', 'product_add' => 'null', 'product_export' => 'null', 'on_demand_import_v2' => 'false', 'regular_import_v2' => 'false', 'quick_fix' => 'false', 'troubleshooter_option' => 'true', 'allow_bc_inv_push' => 'false', 'allow_mg_rest_inv_push' => 'false', 'allow_shopify_inv_push' => 'false', 'allow_teapplix_inv_push' => 'false', 'allow_magento_soap_tracking_no_push' => 'false', 'popup_shipping_label' => 'true', 'api_key' => '5c587aaaba338f34c99e0b9837f24ede', 'api_secret' => '699e8f73a53774d36eb687e316b7327dc137f70beabcaa1e00d7ce4e9197fb96', 'store_api_key' => 'null', 'import_ready_for_shipment' => 'false', 'ready_to_ship' => 'true', 'import_shipped' => 'true', 'gen_barcode_from_sku' => 'true', 'import_upc' => 'true', 'large_popup' => 'true', 'multiple_lines_per_sku_accepted' => 'true', 'allow_duplicate_id' => 'true' }
      expect(response.status).to eq(200)
      expect(se_store.shipping_easy_credential.multiple_lines_per_sku_accepted).to eq(true)
    end
  end

  describe 'Shipstation' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @ship_store = Store.create(name: 'Shipstation', status: true, store_type: 'Shipstation API 2', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true)
      ship_store_credentials = ShipstationRestCredential.create(api_key: '14ccf1296c2043cb9076b90953b7ea9b', api_secret: 'e6fc8ff9f7a7411180d2960eb838e2ca', last_imported_at: nil, store_id: @ship_store.id, created_at: '2021-03-26 08:23:45', updated_at: '2021-05-10 07:57:55', shall_import_awaiting_shipment: true, shall_import_shipped: false, warehouse_location_update: false, shall_import_customer_notes: true, shall_import_internal_notes: true, regular_import_range: 3, gen_barcode_from_sku: false, shall_import_pending_fulfillment: false, quick_import_last_modified: nil, use_chrome_extention: true, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: false, allow_duplicate_order: false, tag_import_option: false, bulk_import: false, order_import_range_days: 14, quick_import_last_modified_v2: '2021-04-22 22:53:15', import_tracking_info: false, last_location_push: nil, use_api_create_label: true, postcode: '29212', label_shortcuts: {"d"=>"All 2", "s"=>"shipping address", "w"=>"weight", "control+b"=>"UPS® Ground", "shift+9"=>"USPS Priority Mail Intl - Flat Rate Padded Envelope", "1"=>"USPS Priority Mail - Flat Rate Envelope", "2"=>"USPS Priority Mail - Flat Rate Padded Envelope", "3"=>"USPS Priority Mail - Regional Rate Box B", "4"=>"USPS Priority Mail - Medium Flat Rate Box", "5"=>"USPS Priority Mail - Large Flat Rate Box", "6"=>"USPS Priority Mail - Package", "c"=>"confirmation", "alt+1"=>"All 5", "alt+2"=>"All 6", "o"=>"All 7"}, disabled_carriers: [], disabled_rates: {"stamps_com"=>[], nil=>nil}, skip_ss_label_confirmation: false, contracted_carriers: ["fedex", "dhl_express_worldwide"], presets: {"All 5"=>"5x5x5(cm)", "All 6"=>"6x6x6(cm)", "All 2"=>"2x2x2(cm)"})
    end

    it 'Verify Shipstation Tags' do
      request.accept = 'application/json'
      post :verify_tags, params: { id: @ship_store.id }
      expect(response.status).to eq(200)
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end

    it 'Shipstation Store Settings' do
      request.accept = 'application/json'
      post :create_update_store, params: { 'file_path' => '', 'inventory_warehouse_id' => '1', 'is_fba' => 'false', 'product_ftp_import' => 'false', 'id' => @ship_store.id, 'name' => 'Shipstation Orders', 'status' => 'true', 'store_type' => 'Shipstation API 2', 'order_date' => 'null', 'created_at' => '2020-10-11T02:29:20.000Z', 'updated_at' => '2021-05-25T07:51:42.000Z', 'thank_you_message_to_customer' => 'null', 'auto_update_products' => 'false', 'update_inv' => 'false', 'on_demand_import' => 'false', 'fba_import' => 'false', 'csv_beta' => 'true', 'is_verify_separately' => 'null', 'split_order' => 'null', 'product_add' => 'null', 'product_export' => 'null', 'on_demand_import_v2' => 'true', 'regular_import_v2' => 'true', 'quick_fix' => 'true', 'troubleshooter_option' => 'true', 'allow_bc_inv_push' => 'false', 'allow_mg_rest_inv_push' => 'false', 'allow_shopify_inv_push' => 'false', 'allow_teapplix_inv_push' => 'false', 'allow_magento_soap_tracking_no_push' => 'false', 'use_chrome_extention' => 'false', 'use_api_create_label' => 'false', 'ss_api_create_label' => 'false', 'switch_back_button' => 'true', 'return_to_order' => 'false', 'auto_click_create_label' => 'false', 'api_key' => '7dfa40094387480992148bb501ed4f7d', 'api_secret' => '1924a70194f84d21bd37644e8b745ee5', 'shall_import_awaiting_shipment' => 'true', 'shall_import_shipped' => 'true', 'shall_import_pending_fulfillment' => 'true', 'shall_import_customer_notes' => 'false', 'shall_import_internal_notes' => 'true', 'hex_barcode' => 'undefined', 'regular_import_range' => '5', 'import_days' => '0,1,2,3,4,5,6', 'warehouse_location_update' => 'false', 'gp_ready_tag_name' => 'GP Ready', 'gp_imported_tag_name' => 'GP Imported', 'gen_barcode_from_sku' => 'true', 'import_upc' => 'true', 'allow_duplicate_order' => 'false', 'tag_import_option' => 'true', 'order_import_range_days' => '190', 'import_tracking_info' => 'true', 'postcode' => '', 'skip_ss_label_confirmation' => 'false', 'enabled_status' => 'true' }
      shipstation = ShipstationRestCredential.where(store_id: @ship_store.id)
      expect(response.status).to eq(200)
      expect(shipstation.first.gen_barcode_from_sku).to eq(true)
    end

    it 'Fetch Label Related Data' do
      request.accept = 'application/json'
      order = FactoryBot.create(:order, increment_id: "SS_3453", store_id: @ship_store.id, store_order_id: '1660160213', ss_label_data: {"orderId"=>785164401, "carrierCode"=>"stamps_com", "serviceCode"=>"usps_first_class_mail", "packageCode"=>"package", "confirmation"=>"delivery", "shipDate"=>"2023-01-09", "weight"=>{"value"=>1.4, "units"=>"ounces", "WeightUnits"=>1}, "dimensions"=>nil, "insuranceOptions"=>{"provider"=>nil, "insureShipment"=>false, "insuredValue"=>0.0}, "internationalOptions"=>{"contents"=>"merchandise", "customsItems"=>nil, "nonDelivery"=>"return_to_sender"}, "advancedOptions"=> {"warehouseId"=>16188, "nonMachinable"=>false, "saturdayDelivery"=>false, "containsAlcohol"=>false, "mergedOrSplit"=>false, "mergedIds"=>[], "parentId"=>nil, "storeId"=>104291, "customField1"=>"153491951039-2338405566005", "customField2"=>"10051435535311", "customField3"=>"", "source"=>"ebay_v2", "billToParty"=>nil, "billToAccount"=>nil, "billToPostalCode"=>nil, "billToCountryCode"=>nil, "billToMyOtherAccount"=>nil}})

      post :fetch_label_related_data, params: { id: order.id, "app"=>true}
      expect(response.status).to eq (200)
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end
  end

  describe 'Veeqo Store' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @veeqo_store = create(:store, name: 'Veeqo test', status: true, store_type: 'Veeqo', inventory_warehouse: @inv_wh)
      create(:veeqo_credential, store_id: @veeqo_store.id)
    end

    it 'Update Veeqo Store' do
      post :create_update_store, params: { id: @veeqo_store.id, store_type: @veeqo_store.store_type, awaiting_fulfillment_status: false }
      expect(response.status).to eq(200)
    end
  end

  describe 'Shopify Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last, on_demand_import: true)
      shopify_store_credentials = ShopifyCredential.create(store_id: shopify_store.id, access_token: 'accesstokenaccesstoken', shop_name: 'test_shop')
    end

    it 'On Demand Import' do
      allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:get_single_order).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/Shopify_test_single_order.yaml'))))

      request.accept = 'application/json'

      shopify_store = Store.where(store_type: 'Shopify').last

      get :get_order_details, params: { order_no: '410382', store_id: shopify_store.id }
      expect(response.status).to eq(200)
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end

    it 'Push Inventory' do
      allow_any_instance_of(Groovepacker::Stores::Exporters::Shopify::Inventory).to receive(:push_inventories).and_return(true)

      shopify_store = Store.where(store_type: 'Shopify').last
      product = FactoryBot.create(:product, store_id: @store.id, store_product_id: '123456')
      product1_inventory = product.product_inventory_warehousess.first
      create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: '1234')
      request.accept = 'application/json'

      get :push_store_inventory, params: { id: shopify_store.id }
      result = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(result['status']).to eq(true)
    end

    it 'Pull Inventory' do
      shopify_store = Store.where(store_type: 'Shopify').last
      product = FactoryBot.create(:product, store_id: @store.id, store_product_id: '123456')
      product1_inventory = product.product_inventory_warehousess.first
      create(:sync_option, product_id: product.id, sync_with_shopify: true, shopify_product_variant_id: '1234')
      request.accept = 'application/json'

      get :pull_store_inventory, params: { id: shopify_store.id }
      result = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(result['status']).to eq(true)
    end

    it 'Update Shopify Store' do
      request.accept = 'application/json'

      store = Store.where(store_type: 'Shopify').last
      post :create_update_store, params: { id: store.id, shop_name: 'Shopify', store_type: store.store_type, add_gp_scanned_tag: true }
      expect(response.status).to eq(200)
    end

    it 'Toggle Sync Option' do
      request.accept = 'application/json'

      shopify_store = Store.where(store_type: 'Shopify').last

      get :toggle_shopify_sync, params: { id: shopify_store.id, type: 'enable' }
      expect(response.status).to eq(200)
    end

    it 'Export Active Products' do
      request.accept = 'application/json'

      get :export_active_products
      expect(response.status).to eq(200)

      product = FactoryBot.create(:product, store_id: @store.id)
      product_sku = FactoryBot.create(:product_sku, sku: 'BEFORE_SKU', product_id: product.id)
      request.accept = 'application/json'

      get :export_active_products
      expect(response.status).to eq(200)
    end
  end

  describe 'Shopline Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopline_store = Store.create(name: 'Shopline', status: true, store_type: 'Shopline', inventory_warehouse: InventoryWarehouse.last, on_demand_import: true)
      shopline_store_credentials = ShoplineCredential.create(store_id: shopline_store.id, access_token: 'accesstokenaccesstoken', shop_name: 'test_shopline')
    end

    it 'On Demand Import' do
      allow_any_instance_of(Groovepacker::ShoplineRuby::Client).to receive(:get_single_order).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/Shopline_test_single_order.yaml'))))

      request.accept = 'application/json'

      shopline_store = Store.where(store_type: 'Shopline').last

      get :get_order_details, params: { order_no: 'SHOPLINE-1001', store_id: shopline_store.id }
      expect(response.status).to eq(200)
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end

    it 'Pull Inventory' do
      shopline_store = Store.where(store_type: 'Shopline').last
      product = FactoryBot.create(:product, store_id: @store.id, store_product_id: '123456')
      product1_inventory = product.product_inventory_warehousess.first
      create(:sync_option, product_id: product.id, sync_with_shopline: true, shopline_product_variant_id: '1234')
      request.accept = 'application/json'

      get :pull_store_inventory, params: { id: shopline_store.id }
      result = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(result['status']).to eq(true)
    end

    it 'Push Inventory' do
      allow_any_instance_of(Groovepacker::Stores::Exporters::Shopline::Inventory).to receive(:push_inventories).and_return(true)

      shopify_store = Store.where(store_type: 'Shopline').last
      product = FactoryBot.create(:product, store_id: @store.id, store_product_id: '123456')
      product1_inventory = product.product_inventory_warehousess.first
      create(:sync_option, product_id: product.id, sync_with_shopline: true, shopline_product_variant_id: '1234')
      request.accept = 'application/json'

      get :push_store_inventory, params: { id: shopify_store.id }
      result = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(result['status']).to eq(true)
    end

    it 'Update Shopline Store' do
      request.accept = 'application/json'

      store = Store.where(store_type: 'Shopline').last
      post :create_update_store, params: { id: store.id, shop_name: 'Shopline', store_type: store.store_type, add_gp_scanned_tag: false }
      expect(response.status).to eq(200)
    end

    it 'Toggle Sync Option' do
      request.accept = 'application/json'

      shopline_store = Store.where(store_type: 'Shopline').last

      get :toggle_shopline_sync, params: { id: shopline_store.id, type: 'enable' }
      expect(response.status).to eq(200)
    end
  end

  describe 'Shippo Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shippo_store = Store.create(name: 'Shippo', status: true, store_type: 'Shippo', inventory_warehouse: InventoryWarehouse.last, on_demand_import: true)
      shippo_store_credentials = ShippoCredential.create(store_id: shippo_store.id, api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08')
    end

    it 'Shippo On Demand Import' do
      allow_any_instance_of(Groovepacker::ShippoRuby::Client).to receive(:get_single_order).and_return(YAML.load(IO.read(Rails.root.join("spec/fixtures/files/Shippo_test_single_order.yaml"))))

      request.accept = 'application/json'

      shippo_store = Store.where(store_type: 'Shippo').last

      get :get_order_details, params: { order_no: '2299714', store_id: shippo_store.id }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
    end

    it 'Shippo Store Settings' do
      request.accept = 'application/json'
      shippo_store = Store.where(store_type: 'Shippo').last
      post :create_update_store, params: { id: shippo_store.id, store_type: shippo_store.store_type, status: true, api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08', generate_barcode_option: 'do_not_generate' }
      expect(response.status).to eq(200)
    end

    it 'Shippo Store Settings for Failed Status' do
      request.accept = 'application/json'
      post :create_update_store, params: { store_type: 'Shippo', status: true, api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08', generate_barcode_option: 'do_not_generate' }
      expect(response.status).to eq(200)
    end
  end

  describe 'Show Store' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = create(:store, name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: @inv_wh, on_demand_import: true)
      create(:shopify_credential, store_id: shopify_store.id, shop_name: 'test_shop')
      shippo_store = create(:store, name: 'Shippo', status: true, store_type: 'Shippo', inventory_warehouse: @inv_wh, on_demand_import: true)
      create(:shippo_credential, store_id: shippo_store.id, api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08')
      veeqo_store = create(:store, name: 'Veeqo test', status: true, store_type: 'Veeqo', inventory_warehouse: @inv_wh)
      create(:veeqo_credential, store_id: veeqo_store.id)
    end

    it 'Show Shopify Store' do
      shopify_store = Store.where(store_type: 'Shopify').last

      get :show, params: { id: shopify_store.id }
      expect(response.status).to eq(200)
    end

    it 'Show Shippo Store' do
      shippo_store = Store.where(store_type: 'Shippo').last

      get :show, params: { id: shippo_store.id }
      expect(response.status).to eq(200)
    end

    it 'Show Veeqo Store' do
      veeqo_store = Store.where(store_type: 'Veeqo').last

      get :show, params: { id: veeqo_store.id }
      expect(response.status).to eq(200)
    end
  end

  describe 'Ebay' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      ebay_store = Store.create(name: 'Ebay', status: true, store_type: 'Ebay', inventory_warehouse: InventoryWarehouse.last, on_demand_import: true)
      ebay_store_credentials = EbayCredentials.create(store_id: ebay_store.id)
    end

    it 'Update Ebay User Token' do
      request.accept = 'application/json'

      eb_store = Store.where(store_type: 'Ebay').last

      get :update_ebay_user_token, params: { id: eb_store.id }
      expect(response.status).to eq(200)
    end

    it 'Delete Ebay Token' do
      request.accept = 'application/json'

      eb_store = Store.where(store_type: 'Ebay').last

      get :delete_ebay_token, params: { id: eb_store.id }
      expect(response.status).to eq(200)
    end
  end

  describe 'Amazon' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      amazon_store = Store.create(name: 'Amazon', status: true, store_type: 'Amazon', inventory_warehouse: InventoryWarehouse.last, on_demand_import: true)
      amazon_store_credentials = AmazonCredentials.create(store_id: amazon_store.id)
    end

    it 'Amazon FBA' do
      request.accept = 'application/json'

      am_store = Store.where(store_type: 'Amazon').last

      get :amazon_fba, params: { store_id: am_store.id }
      expect(response.status).to eq(200)
    end

    it 'Update Amazon Store' do
      request.accept = 'application/json'

      store = Store.where(store_type: 'Amazon').last
      post :create_update_store, params: { id: store.id, store_type: store.store_type, status: true }
      expect(response.status).to eq(200)
    end
  end
end
