# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryBot.create(:access_restriction)
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    csv_mapping = FactoryBot.create(:csv_mapping, store_id: @store.id)
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
        post :import_xml, params: { xml: IO.read(Rails.root.join("spec/fixtures/files/order_import_xml#{order_num}.xml")), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false }
        expect(response.status).to eq(200)
      end

      import_item = ImportItem.find_by_store_id(@store.id)
      expect(Order.all.count).to eq(4)
      expect(Product.all.count).to eq(5)
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

      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/se_shipment_v2.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)

      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.status).to eq('completed')
    end

    it 'Import SE QF Range Orders' do
      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/SE_test_qf_range_orders.yaml'))))

      request.accept = 'application/json'

      se_store = Store.where(store_type: 'ShippingEasy').last

      get :import_for_ss, params: { store_id: se_store.id, days: 0, import_type: 'range_import', import_date: 'null', start_date: '2020-08-03 09:00:25', end_date: '2020-08-03 21:00:25', order_date_type: 'modified', order_id: 'null'}
      expect(response.status).to eq(200)
      expect(Order.count).to eq(6)
      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.success_imported).to eq(6)
      expect(se_import_item.import_type).to eq('range_import')
      expect(se_import_item.status).to eq('completed')
    end
  end

  describe 'Shopify Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last)
      shopify_store_credentials = ShopifyCredential.create(shop_name: 'shopify_test', access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopify_store.id, shopify_status: 'open', shipped_status: true, unshipped_status: true, partial_status: true, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: true)
    end

    it 'Import Orders' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:product).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_product.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)

      shopify_import_item = ImportItem.find_by_store_id(shopify_store.id)
      expect(shopify_import_item.status).to eq('completed')
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

      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_response_from_shipstation).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:remove_gp_tags_from_ss).and_return(true)
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:should_fetch_shipments?).and_return(false)
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)

      ss_import_item = ImportItem.find_by_store_id(ss_store.id)
      expect(ss_import_item.status).to eq('completed')
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
end
