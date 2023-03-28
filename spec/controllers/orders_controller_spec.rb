# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
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
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s)
  end

  after do
    @tenant.destroy
  end

  describe 'CSV Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Import CSV Orders' do
      order_import_summary = OrderImportSummary.create(user: User.first, status: 'completed', import_summary_type: 'import_orders', display_summary: false)
      import_item = ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id, import_type: 'regular')

      request.accept = 'application/json'

      expect_any_instance_of(Groovepacker::Orders::Xml::Import).to receive(:check_count_is_equle?).and_return(true)

      (1..4).to_a.each do |order_num|
        post :import_xml, params: { xml: IO.read(Rails.root.join("spec/fixtures/files/order_import_xml#{order_num}.xml")).gsub('<storeId>4</storeId>', "<storeId>#{@store.id}</storeId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false }
        expect(response.status).to eq(200)
      end

      expect(Order.all.count).to eq(4)
      expect(Product.all.count).to eq(5)
    end

    it 'Import CSV Order with Aliased Item' do
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product, name: 'PRODUCT2')
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order_import_summary = OrderImportSummary.create(user: User.first, status: 'completed', import_summary_type: 'import_orders', display_summary: false)
      ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id, import_type: 'regular')

      request.accept = 'application/json'
      allow_any_instance_of(Groovepacker::Orders::Xml::Import).to receive(:check_count_is_equle?).and_return(true)

      post :import_xml, params: { xml: IO.read(Rails.root.join('spec/fixtures/files/order_import_aliased_xml.xml')).gsub('<storeId>4</storeId>', "<storeId>#{@store.id}</storeId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false }
      expect(response.status).to eq(200)

      # Alias Product
      Groovepacker::Products::Aliasing.new(result: { 'status' => true }, params_attrs: { id: product.id, product_alias_ids: [product2.id] }, current_user: @user).set_alias

      # Update Order CSV Import
      $redis.set("import_action_#{Apartment::Tenant.current}", 'update_order')

      ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id, import_type: 'regular')
      post :import_xml, params: { xml: IO.read(Rails.root.join('spec/fixtures/files/order_import_aliased_xml.xml')).gsub('<storeId>4</storeId>', "<storeId>#{@store.id}</storeId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false }
      expect(response.status).to eq(200)

      expect(Order.all.count).to eq(1)
      expect(OrderItem.last.qty).to eq(12)
      expect(Product.all.count).to eq(1)
    end
  end

  describe 'Bulk Order Operations' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Delete Bulk Order' do
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: @store, prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1, name: product.name)

      request.accept = 'application/json'

      post :delete_orders, params: { select_all: true, status: 'all', user_id: @user.id }

      expect(response.status).to eq(200)
    end
  end

  describe 'Shipworks Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    let(:order_xml) { IO.read(Rails.root.join('spec/fixtures/files/sw_order_import.xml')) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      sw_store = Store.create(name:'Shipworks', status:true, store_type:'Shipworks', inventory_warehouse: InventoryWarehouse.last)
      @sw_store_credential = ShipworksCredential.create(store_id: sw_store.id, auth_token: "sw_auth_token==", shall_import_ignore_local: true)
    end

    it 'Import Shipworks Orders' do
      request.accept = 'application/xml'
      request.env['HTTP_USER_AGENT'] = 'shipworks'
      expect {
        post :import_shipworks, params: { auth_token: @sw_store_credential.auth_token }, body: order_xml
      }.to change { OrderItem.count }.by(3)
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

    it 'Import SE Shipment Handling V2 Orders' do
      se_store = Store.where(store_type: 'ShippingEasy').last

      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: se_store, prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1, name: product.name)

      order2 = FactoryBot.create(:order, increment_id: 'ORDER2', status: 'awaiting', store: se_store, prime_order_id: '1660159733', store_order_id: '1660159733')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order2, name: product.name)

      order3 = FactoryBot.create(:order, increment_id: 'ORDER3', status: 'awaiting', store: se_store, prime_order_id: '1660160773', store_order_id: '1660160773')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order3, name: product.name)

      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/se_shipment_v2.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)

      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.status).to eq('completed')
    end

    it 'Import SE QF Range Orders' do
      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/SE_test_qf_range_orders.yaml'))))

      request.accept = 'application/json'

      se_store = Store.where(store_type: 'ShippingEasy').last

      get :import_for_ss, params: { store_id: se_store.id, days: 0, import_type: 'range_import', import_date: 'null', start_date: '2020-08-03 09:00:25', end_date: '2020-08-03 21:00:25', order_date_type: 'modified', order_id: 'null' }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(6)
      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.success_imported).to eq(6)
      expect(se_import_item.import_type).to eq('range_import')
      expect(se_import_item.status).to eq('completed')
    end

    it 'Import All shows import Running' do
      OrderImportSummary.create(status: 'in_progress')

      request.accept = 'application/json'

      get :import_all

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('Import is in progress')
    end

    it 'Import for single store shows import Running' do
      se_store = Store.where(store_type: 'ShippingEasy').last
      ImportItem.create(status: 'in_progress', store: se_store)

      request.accept = 'application/json'
      get :import, params: { store_id: se_store.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('Import is in progress')
    end

    it 'Range or Quickfix Import shows import Running' do
      se_store = Store.where(store_type: 'ShippingEasy').last
      ImportItem.create(status: 'in_progress', store: se_store)

      request.accept = 'application/json'
      get :import_for_ss, params: { store_id: se_store.id, days: 0, import_type: 'range_import', start_date: '2020-09-26%2007:22:39', end_date: '2020-09-27%2007:22:39', order_date_type: 'modified' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('An Import is already in queue or running, please wait for it to complete!')
    end

    it 'SE Import for single store shows import Cancelled' do
      se_store = Store.where(store_type: 'ShippingEasy').last
      ImportItem.create(status: 'in_progress', store: se_store)

      request.accept = 'application/json'
      get :cancel_import, params: { 'store_id' => se_store.id, 'order' => { 'store_id' => se_store.id } }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('No imports are in progress')
    end
  end

  describe 'Shopify Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last)
      shopify_store_credentials = ShopifyCredential.create(shop_name: 'shopify_test', access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopify_store.id, shopify_status: 'open', shipped_status: true, unshipped_status: true, partial_status: true, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false)
    end

    it 'Import Orders' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_product.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      @tenant.uniq_shopify_import = true
      @tenant.save

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)

      shopify_import_item = ImportItem.find_by_store_id(shopify_store.id)
      expect(shopify_import_item.status).to eq('completed')
    end

    it 'Same Job Id Multiple Time Import Orders' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_product.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      @tenant.uniq_shopify_import = true
      @tenant.save
      sleep 3
      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)
    end

    it 'Orders Import Job Created Just 3 Second Before.' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_product.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      @tenant.uniq_shopify_import = true
      @tenant.save
      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)
    end
  end

  describe 'Shipstation API 2 Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      ss_store = Store.create(name: 'Shipstation API 2', status: true, store_type: 'Shipstation API 2', inventory_warehouse: InventoryWarehouse.last, on_demand_import_v2: true, regular_import_v2: true, troubleshooter_option: true)
      ss_store_credentials = ShipstationRestCredential.create(api_key: 'shipstationapiv2shipstationapiv2', api_secret: 'shipstationapiv2shipstationapiv2', store_id: ss_store.id, shall_import_awaiting_shipment: false, shall_import_shipped: true, warehouse_location_update: false, shall_import_customer_notes: true, shall_import_internal_notes: true, regular_import_range: 3, gen_barcode_from_sku: true, shall_import_pending_fulfillment: false, use_chrome_extention: false, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: true, allow_duplicate_order: true, tag_import_option: true, bulk_import: false, order_import_range_days: 30, import_tracking_info: true)
    end

    it 'Import Orders' do
      ss_store = Store.where(store_type: 'ShipStation API 2').last

      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_response_from_shipstation).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:remove_gp_tags_from_ss).and_return(true)
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:should_fetch_shipments?).and_return(false)
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(3)

      ss_import_item = ImportItem.find_by_store_id(ss_store.id)
      expect(ss_import_item.status).to eq('completed')
    end

    it 'SS  Range Import' do
      store = Store.where(name: 'GrooveShipStationTest')
      if store.present?
        store_id = store.id
        Store.find(store_id).destroy
      end
      ss_store = Store.create!(name: 'GrooveShipStationTest', status: true, store_type: 'Shipstation API 2', order_date: nil, inventory_warehouse_id: @inv_wh.id, thank_you_message_to_customer: nil, auto_update_products: false, update_inv: false, on_demand_import: false, fba_import: false, csv_beta: true, is_verify_separately: nil, split_order: 'null', on_demand_import_v2: true, regular_import_v2: false, quick_fix: true, troubleshooter_option: false)
      ShipstationRestCredential.create(api_key: '14ccf1296c2043cb9076b90953b7ea9b', api_secret: 'e6fc8ff9f7a7411180d2960eb838e2ca', last_imported_at: '2021-07-12', store_id: ss_store.id, created_at: '2021-04-01 16:53:35', updated_at: '2021-07-13 12:52:36', shall_import_awaiting_shipment: true, shall_import_shipped: true, warehouse_location_update: false, shall_import_customer_notes: false, shall_import_internal_notes: false, regular_import_range: 3, gen_barcode_from_sku: false, shall_import_pending_fulfillment: true, quick_import_last_modified: '2021-07-12 12:50:44', use_chrome_extention: false, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: false, allow_duplicate_order: false, tag_import_option: true, bulk_import: false, quick_import_last_modified_v2: '2021-07-06 14:39:53', order_import_range_days: 30, import_tracking_info: false, last_location_push: nil, use_api_create_label: true, postcode: '27502', disabled_carriers: [], label_shortcuts: { 'w' => 'weight', 'p' => 'USPS First Class Mail - Letter' }, skip_ss_label_confirmation: false, disabled_rates: { 'stamps_com' => [] })
      ImportItem.create(status: 'completed', store: ss_store)
      tenant = Apartment::Tenant.current
      tenant = Tenant.where(name: tenant.to_s).first
      Order.create(increment_id: 'CSV-100151', order_placed_time: '2021-04-14 23:52:17', sku: nil, customer_comments: nil, store_id: ss_store.id, qty: nil, price: nil, firstname: 'Alpha', lastname: 'Tester', email: 'alphatester@yopmail.com', address_1: '110 COBBLESTONE CIR', address_2: '', city: 'NORTH LITTLE ROCK', state: 'AR', postcode: '72116-3739', country: 'US', method: nil, created_at: '2021-07-14 08:35:37', updated_at: '2021-07-14 08:35:37', notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'onhold', scanned_on: nil, tracking_num: nil, company: nil, packing_user_id: nil, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: 0.0, notes_from_buyer: nil, weight_oz: 8, non_hyphen_increment_id: 'CSV100151', note_confirmation: false, inaccurate_scan_count: 0, scan_start_time: nil, reallocate_inventory: false, last_suggested_at: nil, total_scan_time: 0, total_scan_count: 0, packing_score: 0, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: false, import_s3_key: nil, last_modified: '2021-04-14 23:53:00', prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: { 'orderId' => 830_373_892, 'carrierCode' => 'stamps_com', 'serviceCode' => 'usps_parcel_select', 'packageCode' => 'package', 'confirmation' => 'none', 'shipDate' => '2021-05-10', 'weight' => { 'value' => 8.0, 'units' => 'ounces', 'WeightUnits' => 1 }, 'dimensions' => nil, 'insuranceOptions' => { 'provider' => nil, 'insureShipment' => false, 'insuredValue' => 0.0 }, 'internationalOptions' => { 'contents' => nil, 'customsItems' => nil, 'nonDelivery' => nil }, 'advancedOptions' => { 'warehouseId' => 82_982, 'nonMachinable' => false, 'saturdayDelivery' => false, 'containsAlcohol' => false, 'mergedOrSplit' => false, 'mergedIds' => [], 'parentId' => nil, 'storeId' => 203_151, 'customField1' => nil, 'customField2' => nil, 'customField3' => nil, 'source' => nil, 'billToParty' => 'my_other_account', 'billToAccount' => nil, 'billToPostalCode' => nil, 'billToCountryCode' => nil, 'billToMyOtherAccount' => nil } }, importer_id: 'worker_0ebe21f3948d557300cd5f77aeaf5afb', clicked_scanned_qty: nil, import_item_id: '21', job_timestamp: nil)
      tenant.gdpr_shipstation = true
      tenant.save
      request.accept = 'application/json'
      get :import_for_ss, params: { 'store_id' => ss_store.id, 'days' => '0', 'import_type' => 'range_import', 'import_date' => 'null', 'start_date' => DateTime.now.in_time_zone - 2.days, 'end_date' => DateTime.now.in_time_zone, 'order_date_type' => 'modified', 'order_id' => 'null' }
      expect(response.status).to eq(200)

      ss_store.destroy
    end

    it 'SS Quick Import' do
      store = Store.where(name: 'GrooveShipStationTest')
      if store.present?
        store_id = store.id
        Store.find(store_id).destroy
      end
      ss_store = Store.create!(name: 'GrooveShipStationTest', status: true, store_type: 'Shipstation API 2', order_date: nil, inventory_warehouse_id: @inv_wh.id, thank_you_message_to_customer: nil, auto_update_products: false, update_inv: false, on_demand_import: false, fba_import: false, csv_beta: true, is_verify_separately: nil, split_order: 'null', on_demand_import_v2: true, regular_import_v2: false, quick_fix: true, troubleshooter_option: false)
      ShipstationRestCredential.create(api_key: '14ccf1296c2043cb9076b90953b7ea9b', api_secret: 'e6fc8ff9f7a7411180d2960eb838e2ca', last_imported_at: '2021-07-12', store_id: ss_store.id, created_at: '2021-04-01 16:53:35', updated_at: '2021-07-13 12:52:36', shall_import_awaiting_shipment: true, shall_import_shipped: true, warehouse_location_update: false, shall_import_customer_notes: false, shall_import_internal_notes: false, regular_import_range: 3, gen_barcode_from_sku: false, shall_import_pending_fulfillment: true, quick_import_last_modified: '2021-07-12 12:50:44', use_chrome_extention: false, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: false, allow_duplicate_order: false, tag_import_option: true, bulk_import: false, quick_import_last_modified_v2: '2021-07-06 14:39:53', order_import_range_days: 30, import_tracking_info: false, last_location_push: nil, use_api_create_label: true, postcode: '27502', disabled_carriers: [], label_shortcuts: { 'w' => 'weight', 'p' => 'USPS First Class Mail - Letter' }, skip_ss_label_confirmation: false, disabled_rates: { 'stamps_com' => [] })
      ImportItem.create(status: 'completed', store: ss_store)
      tenant = Apartment::Tenant.current
      tenant = Tenant.where(name: tenant.to_s).first
      Order.create(increment_id: 'CSV-100151', order_placed_time: '2021-04-14 23:52:17', sku: nil, customer_comments: nil, store_id: ss_store.id, qty: nil, price: nil, firstname: 'Alpha', lastname: 'Tester', email: 'alphatester@yopmail.com', address_1: '110 COBBLESTONE CIR', address_2: '', city: 'NORTH LITTLE ROCK', state: 'AR', postcode: '72116-3739', country: 'US', method: nil, created_at: '2021-07-14 08:35:37', updated_at: '2021-07-14 08:35:37', notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'onhold', scanned_on: nil, tracking_num: nil, company: nil, packing_user_id: nil, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: 0.0, notes_from_buyer: nil, weight_oz: 8, non_hyphen_increment_id: 'CSV100151', note_confirmation: false, inaccurate_scan_count: 0, scan_start_time: nil, reallocate_inventory: false, last_suggested_at: nil, total_scan_time: 0, total_scan_count: 0, packing_score: 0, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: false, import_s3_key: nil, last_modified: '2021-04-14 23:53:00', prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: { 'orderId' => 830_373_892, 'carrierCode' => 'stamps_com', 'serviceCode' => 'usps_parcel_select', 'packageCode' => 'package', 'confirmation' => 'none', 'shipDate' => '2021-05-10', 'weight' => { 'value' => 8.0, 'units' => 'ounces', 'WeightUnits' => 1 }, 'dimensions' => nil, 'insuranceOptions' => { 'provider' => nil, 'insureShipment' => false, 'insuredValue' => 0.0 }, 'internationalOptions' => { 'contents' => nil, 'customsItems' => nil, 'nonDelivery' => nil }, 'advancedOptions' => { 'warehouseId' => 82_982, 'nonMachinable' => false, 'saturdayDelivery' => false, 'containsAlcohol' => false, 'mergedOrSplit' => false, 'mergedIds' => [], 'parentId' => nil, 'storeId' => 203_151, 'customField1' => nil, 'customField2' => nil, 'customField3' => nil, 'source' => nil, 'billToParty' => 'my_other_account', 'billToAccount' => nil, 'billToPostalCode' => nil, 'billToCountryCode' => nil, 'billToMyOtherAccount' => nil } }, importer_id: 'worker_0ebe21f3948d557300cd5f77aeaf5afb', clicked_scanned_qty: nil, import_item_id: '21', job_timestamp: nil)
      tenant.gdpr_shipstation = true
      tenant.save

      request.accept = 'application/json'
      get :import_for_ss, params: { 'store_id' => ss_store.id, 'days' => '0', 'import_type' => 'quickfix', 'import_date' => DateTime.now.in_time_zone, 'start_date' => 'null', 'end_date' => 'null', 'order_date_type' => 'null', 'order_id' => 'CSV-100151' }

      expect(response.status).to eq(200)
      ss_store.destroy
    end

    it 'SS Import for single store shows import Cancelled' do
      ss_store = Store.where(store_type: 'ShipStation API 2').last
      ImportItem.create(status: 'in_progress', store: ss_store)

      request.accept = 'application/json'
      get :cancel_import, params: { 'store_id' => ss_store.id, 'order' => { 'store_id' => ss_store.id } }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to include('No imports are in progress')
    end
  end

  describe 'Order Search' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      product = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCTTEST')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCTTEST')

      order = FactoryBot.create(:order, increment_id: '100', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: '10', status: 'awaiting', tracking_num: '100', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: 'T', status: 'awaiting', tracking_num: '9400111298370613423837', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: 'TR', status: 'awaiting', tracking_num: '12345', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: '1234512345', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: 'TRA', status: 'awaiting', tracking_num: '1234512345', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)
    end

    it 'find order search by tracking number ending' do
      post :search, params: { search: '837', order: 'DESC', limit: 20, offset: 0, product_search_toggle: true }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['orders'].first['ordernum']).to eq('T')
      expect(result['orders'].first['tracking_num']).to eq('9400111298370613423837')
    end
  end

  describe 'Orders ' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    describe 'Delete Packing Cam image' do
      it 'Successfully destroy packing cam image' do
        order = FactoryBot.create :order, store_id: @store.id
        current_tenant = Apartment::Tenant.current
        image = { image: 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII', content_type: 'image/png', original_filename: 'sample_image.png' }
        file_name = "packing_cams/#{SecureRandom.random_number(20_000)}_#{Time.current.strftime('%d_%b_%Y_%I__%M_%p')}_#{current_tenant}_#{order.id}_" + image[:original_filename].delete('#')
        GroovS3.create_image(current_tenant, file_name, image[:image], image[:content_type])
        url = ENV['S3_BASE_URL'] + '/' + current_tenant + '/image/' + file_name
        packing_cam = order.packing_cams.create(url: url, user: @user, username: @user&.username)

        post :remove_packing_cam_image, params: { id: order.id, packing_cam_id: packing_cam.id }
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['status']).to be_truthy
      end

      it 'does not destroy Packing cam with invalid id' do
        post :remove_packing_cam_image, params: { id: 123, packing_cam_id: nil }
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['status']).to be_falsy
      end

      it 'update ss label data' do
        order = FactoryBot.create :order, store_id: @store.id

        params = { order_number: order.increment_id, ss_label_data: { shipping_address: { name: 'sigma tester', address1: '781 WARWICK AVE', address2: nil, state: 'RI', postal_code: '02888-2601', city: 'WARWICKs', country: 'US' }, dimensions: { units: 'centimeters', length: 14, width: 65, height: 43 }, weight: { value: 13, units: 'pounds' } } }

        post :update_ss_label_order_data, params: params
        expect(response.status).to eq(200)
        expect(order.reload.ss_label_data['weight']['value']).to eq '13'
      end
    end

    it 'Print Packing Slip 4 x 4' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester',username: 'packing_slip_tester1', packing_slip_size: '4 x 4')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip 4 x 2' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester',username: 'packing_slip_tester2', packing_slip_size: '4 x 2')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester',username: 'packing_slip_tester1', packing_slip_size: '8.5 x 11')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Add item to order if product exists' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')

      post :add_item_to_order, params: { id: order.id, productids: [product.id.to_s] }
      expect(response.status).to eq(200)

      post :add_item_to_order, params: { id: order.id, productids: [product.id.to_s] }
      expect(order.order_items.last.qty).to eq(2)
      expect(order.order_items.last.scanned_qty).to eq(1)
    end

    it 'Add item to order without product' do
      order = FactoryBot.create :order, store_id: @store.id

      post :add_item_to_order, params: { id: order.id }
      expect(response.status).to eq(200)
    end

    it 'Add item to order with scanned status' do
      order = FactoryBot.create :order, store_id: @store.id, status: 'scanned'

      post :add_item_to_order, params: { id: order.id }
      expect(response.status).to eq(200)
    end

    it 'Show Order' do
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store,name: "ss_store", store_type: "Shipstation API 2",inventory_warehouse: @inv_wh, status: true) 
      ss_credential = FactoryBot.create(:shipstation_rest_credential, store_id: store.id) 
      order = FactoryBot.create :order, store_id: @store.id
      params = {id: order.id}

      get :show, params: params
      expect(response.status).to eq(200)
    end

    it 'Get Real Time Rates' do
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store,name: "ss_store", store_type: "Shipstation API 2",inventory_warehouse: @inv_wh, status: true) 
      ss_credential = FactoryBot.create(:shipstation_rest_credential, store_id: store.id) 
      order = FactoryBot.create :order, store_id: @store.id
      params = { credential_id: ss_credential.id, carrier_code: "fedex", post_data: {weight: '10',fromPostalCode: '10005',toState: 'South Carolina',toCountry: 'US',toPostalCode: '25918-2743',confirmation_code: 'none'} }
      
      post :get_realtime_rates, params: params
      expect(response.status).to eq(200)
    end

    it 'Record Exception' do
      order = FactoryBot.create :order, store_id: @store.id

      request.accept = 'application/json'

      post :record_exception, params: { id: order.id, reason: '' }
      expect(response.status).to eq(200)
    end
    
    it 'Saved By Pass Log' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      product_sku = FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      request.accept = 'application/json'
      
      post :save_by_passed_log, params: { id: order.id, sku: product_sku.sku }
      expect(response.status).to eq (200)
    end

    it 'Generate pick list' do
      order = FactoryBot.create :order, store_id: @store.id
      request.accept = 'application/json'

      post :generate_pick_list, params:{ orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'prints activity log' do
      order = FactoryBot.create(:order, store_id: @store.id)
      order.addactivity('TEST ACTIVITY', @user.username)

      request.accept = 'application/json'

      get :print_activity_log, params: { id: order.id }
      expect(response.status).to eq(200)
    end

    it 'Does not prints activity log if id is wrong' do
      request.accept = 'application/json'

      get :print_activity_log, params: { id: SecureRandom.random_number(50_000) }
      expect(response.status).to eq(200)
    end

    it 'Change Orders Status' do
      user_role = FactoryBot.create(:role, name: 'tester_role1', add_edit_users: true)
      @user = FactoryBot.create(:user, name: 'Manager User', username: 'Order_tester', role: user_role, confirmation_code: 123412)
      request.accept = 'application/json'

      post :change_orders_status, params: {id: @user.id, confirmation_code: @user.confirmation_code}
      expect(response.status).to eq(200)
    end

    it 'Import Cancelled' do
      user = User.last
      ss_store = Store.where(store_type: 'CSV').last
      OrderImportSummary.create(status: 'in_progress', user_id: user.id, import_summary_type: 'import_orders', display_summary: true)

      allow(ElixirApi::Processor::CSV::OrdersToXML).to receive(:cancel_import) { true }

      request.accept = 'application/json'
      get :cancel_import, params: { store_id: ss_store.id, order: {store_id: ss_store.id} }
      expect(response.status).to eq(200)
    end

    it 'App Orders params' do
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil, customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: nil, importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-BLACK-L', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductKitSkus.create(product_id: product1.id, option_product_id: product2.id, qty: 1, packing_order: 50)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'

      post :index, params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true }
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)

      post :index, params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1' }
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)
    end
  end
end
