# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)
    @generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true,
                                         add_edit_order_items: true)
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
      order_import_summary = OrderImportSummary.create(user: User.first, status: 'completed',
                                                       import_summary_type: 'import_orders', display_summary: false)
      import_item = ImportItem.create(status: 'not_started', store_id: @store.id,
                                      order_import_summary_id: order_import_summary.id, import_type: 'regular')

      request.accept = 'application/json'

      expect_any_instance_of(Groovepacker::Orders::Xml::Import).to receive(:check_count_is_equle?).and_return(true)

      (1..4).to_a.each do |order_num|
        post :import_xml,
             params: {
               xml: IO.read(Rails.root.join("spec/fixtures/files/order_import_xml#{order_num}.xml")).gsub('<storeId>4</storeId>',
                                                                                                          "<storeId>#{@store.id}</storeId>").gsub('<importSummaryId>1</importSummaryId>', "<importSummaryId>#{order_import_summary.id}}</importSummaryId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false
             }
        expect(response.status).to eq(200)
      end

      expect(Order.all.count).to eq(4)
      expect(Product.all.count).to eq(5)
    end

    it 'Import CSV Order with Aliased Item' do
      product = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order_import_summary = OrderImportSummary.create(user: User.first, status: 'completed',
                                                       import_summary_type: 'import_orders', display_summary: false)
      ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id,
                        import_type: 'regular')

      time_in_csv = '2020-07-31 08:49:02'

      request.accept = 'application/json'
      allow_any_instance_of(Groovepacker::Orders::Xml::Import).to receive(:check_count_is_equle?).and_return(true)

      post :import_xml,
           params: {
             xml: IO.read(Rails.root.join('spec/fixtures/files/order_import_aliased_xml.xml')).gsub('<storeId>4</storeId>',
                                                                                                    "<storeId>#{@store.id}</storeId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false
           }
      expect(response.status).to eq(200)

      # Alias Product
      Groovepacker::Products::Aliasing.new(result: { 'status' => true },
                                           params_attrs: { id: product.id, product_alias_ids: [product2.id] }, current_user: @user).set_alias

      # Update Order CSV Import
      $redis.set("import_action_#{Apartment::Tenant.current}", 'update_order')

      ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id,
                        import_type: 'regular')
      post :import_xml,
           params: {
             xml: IO.read(Rails.root.join('spec/fixtures/files/order_import_aliased_xml.xml')).gsub('<storeId>4</storeId>',
                                                                                                    "<storeId>#{@store.id}</storeId>"), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false
           }
      expect(response.status).to eq(200)

      expect(Order.first.order_placed_time.utc).to eq(Time.find_zone(GeneralSetting.new_time_zone).parse(time_in_csv).utc)
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
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: @store,
                                         prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1,
                                     name: product.name)

      request.accept = 'application/json'

      post :delete_orders, params: { select_all: true, status: 'all', user_id: @user.id }

      expect(response.status).to eq(200)
    end

    it 'Assign Bulk Order to Users' do
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: @store,
                                         prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1,
                                     name: product.name)

      request.accept = 'application/json'

      order = FactoryBot.create :order, store_id: @store.id

      post :assign_orders_to_users, as: :json, params:{sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{id: order.id}], product_search_toggle: 'true', export_type: '', users: [@user.username]}
      expect(response.status).to eq(200)
    end

    it 'Un-Assign Bulk Order to Users' do
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: @store,
                                         prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1,
                                     name: product.name)

      request.accept = 'application/json'

      order = FactoryBot.create :order, store_id: @store.id

      post :deassign_orders_from_users, as: :json, params:{sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{id: order.id}], product_search_toggle: 'true', export_type: '', users: [@user.username]}
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

      sw_store = Store.create(name: 'Shipworks', status: true, store_type: 'Shipworks',
                              inventory_warehouse: InventoryWarehouse.last)
      @sw_store_credential = ShipworksCredential.create(store_id: sw_store.id, auth_token: 'sw_auth_token==',
                                                        shall_import_ignore_local: true)
    end

    it 'Import Shipworks Orders' do
      request.accept = 'application/xml'
      request.env['HTTP_USER_AGENT'] = 'shipworks'
      expect do
        post :import_shipworks, params: { auth_token: @sw_store_credential.auth_token }, body: order_xml
      end.to change { OrderItem.count }.by(3)
      expect(response.status).to eq(200)
    end
  end

  describe 'ShippingEasy Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      se_store = Store.create(name: 'ShippingEasy', status: true, store_type: 'ShippingEasy',
                              inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true)
      se_store_credentials = ShippingEasyCredential.create(store_id: se_store.id,
                                                           api_key: 'apikeyapikeyapikeyapikeyapikeyse', api_secret: 'apisecretapisecretapisecretapisecretapisecretapisecretapisecrets', import_ready_for_shipment: false, import_shipped: true, gen_barcode_from_sku: false, popup_shipping_label: false, ready_to_ship: true, import_upc: true, allow_duplicate_id: true)
    end

    it 'Import SE Shipment Handling V2 Orders' do
      @tenant.update(loggly_se_imports: true)
      se_store = Store.where(store_type: 'ShippingEasy').last

      product = FactoryBot.create(:product, name: 'PRODUCT1')
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCT1')

      order1 = FactoryBot.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: se_store,
                                         prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1,
                                     name: product.name)

      order2 = FactoryBot.create(:order, increment_id: 'ORDER2', status: 'awaiting', store: se_store,
                                         prime_order_id: '1660159733', store_order_id: '1660159733')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order2,
                                     name: product.name)

      order3 = FactoryBot.create(:order, increment_id: 'ORDER3', status: 'awaiting', store: se_store,
                                         prime_order_id: '1660160773', store_order_id: '1660160773')
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order3,
                                     name: product.name)

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

      get :import_for_ss,
          params: { store_id: se_store.id, days: 0, import_type: 'range_import', import_date: 'null',
                    start_date: '2020-08-03 09:00:25', end_date: '2020-08-03 21:00:25', order_date_type: 'modified', order_id: 'null' }
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
      get :import_for_ss,
          params: { store_id: se_store.id, days: 0, import_type: 'range_import', start_date: '2020-09-26%2007:22:39',
                    end_date: '2020-09-27%2007:22:39', order_date_type: 'modified' }

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

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify',
                                   inventory_warehouse: InventoryWarehouse.last)
      shopify_store_credentials = ShopifyCredential.create(shop_name: 'shopify_test',
                                                           access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopify_store.id, shopify_status: 'open', shipped_status: true, unshipped_status: true, partial_status: true, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false)
    end

    it 'Import Orders' do
      @tenant.update(loggly_shopify_imports: true)
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
      expect(OrderTag.count).to be > (2)
      expect(OrderTag.pluck(:name)).to include('test1', 'test2')

      shopify_import_item = ImportItem.find_by_store_id(shopify_store.id)
      expect(shopify_import_item.status).to eq('completed')
    end

    it 'Same Job Id Multiple Time Import Orders' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).not_to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_product.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
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
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopify_import-2", job_count: 1)
      @tenant.uniq_shopify_import = true
      @tenant.save
      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)
    end
  end

  describe 'Shopline Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopline_store = Store.create(name: 'Shopline', status: true, store_type: 'Shopline',
                                    inventory_warehouse: InventoryWarehouse.last)
      shopline_store_credentials = ShoplineCredential.create(shop_name: 'shopify_test',
                                                             access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopline_store.id, shopline_status: 'open', shipped_status: false, unshipped_status: false, partial_status: false, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false)
    end

    it 'Import Orders when all import switches are off' do
      shopline_store = Store.where(store_type: 'Shopline').last

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      @tenant.uniq_shopify_import = true
      @tenant.save

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)

      shopify_import_item = ImportItem.find_by_store_id(shopline_store.id)
      expect(shopify_import_item.status).to eq('failed')
    end

    it 'Import Orders' do
      shopline_store = Store.where(store_type: 'Shopline').last
      shopline_store.shopline_credential.update(shipped_status: true)

      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_product.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      @tenant.uniq_shopify_import = true
      @tenant.save

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)

      shopify_import_item = ImportItem.find_by_store_id(shopline_store.id)
      expect(shopify_import_item.status).to eq('completed')
    end

    it 'Same Job Id Multiple Time Import Orders' do
      shopline_store = Store.where(store_type: 'Shopline').last

      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).not_to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).not_to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_product.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopline_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopline_import-2", job_count: 1)
      @tenant.uniq_shopify_import = true
      @tenant.save
      sleep 3
      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)
    end

    it 'Orders Import Job Created Just 3 Second Before.' do
      shopline_store = Store.where(store_type: 'Shopline').last

      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).not_to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShoplineRuby::Client).not_to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopline_test_product.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopline_import-2", job_count: 1)
      UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex,
                          job_timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S.%L'), job_id: "#{Apartment::Tenant.current}_shopline_import-2", job_count: 1)
      @tenant.uniq_shopify_import = true
      @tenant.save
      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)
    end
  end

  describe 'Shippo Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shippo_store = Store.create(name: 'Shippo', status: true, store_type: 'Shippo',
                                  inventory_warehouse: InventoryWarehouse.last)
      shippo_store_credentials = ShippoCredential.create(store_id: shippo_store.id,
                                                         api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08', generate_barcode_option: 'do_not_generate', import_awaitpay: true)
    end

    it 'Import Orders' do
      shippo_store = Store.where(store_type: 'Shippo').last

      expect_any_instance_of(Groovepacker::ShippoRuby::Client).to receive(:orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/Shippo_test_order.yaml'))))
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")
      @tenant.save

      get :import_all
      expect(response.status).to eq(200)
    end

    # it 'Shippo Import by Range' do
    #   allow_any_instance_of(Groovepacker::ShippoRuby::Client).to receive(:get_single_order).and_return(YAML.load(IO.read(Rails.root.join("spec/fixtures/files/Shippo_test_single_order.yaml"))))

    #   request.accept = 'application/json'

    #   shippo_store = Store.where(store_type: 'Shippo').last

    #   get :import_for_ss, params: { store_id: shippo_store.id, days: 0, import_type: 'range_import', start_date: '2023-04-10T13:26:01.926Z', end_date: '2023-04-13T13:26:01.926Z' }
    #   expect(response.status).to eq(200)
    # end
  end

  describe 'Veeqo Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    let(:success) { 200 }
    let(:parsed_response) { YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/veeqo_test_order.yaml'))) }
    let(:response_headers) { { 'x-total-pages-count' => '2' } }
    let(:veeqo_response) do
      instance_double(HTTParty::Response, success?: success, parsed_response:, headers: response_headers)
    end
    let(:mock_response) do
      instance_double(
        'Response',
        body: {
          'data' => {
            'products' => {
              'nodes' => [
                {
                  'id' => 'gid://shopify/Product/8215423844641',
                  'title' => 'VANS | AUTHENTIC | (MULTI EYELETS) | GRADIENT/CRIMSON'
                }
              ]
            }
          }
        }
      )
    end
    let(:mock_without_response) do
      instance_double(
        'Response',
        body: {
          'data' => {
            'products' => {
              'nodes' => [
                {}
              ]
            }
          }
        }
      )
    end

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(HTTParty).to receive(:get).and_return(veeqo_response)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @veeqo_store = create(:store, :veeqo, inventory_warehouse: @inv_wh) do |store|
        store.veeqo_credential.update(store_id: store.id, shall_import_customer_notes: true,
                                      allow_duplicate_order: true, shall_import_internal_notes: true, gen_barcode_from_sku: true, shipped_status: true, awaiting_amazon_fulfillment_status: true, awaiting_fulfillment_status: true, import_shipped_having_tracking: true)
      end
    end

    it 'Import Orders' do
      @tenant.update(loggly_veeqo_imports: true)
      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end

    it 'Import Orders when cancelled order is already exist' do
      create(:order, store_id: @veeqo_store.id, status: 'cancelled', increment_id: '1744', store_order_id: '331856255', veeqo_allocation_id: '246838519')

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end

    it 'Import Orders with Allow duplicate order' do
      create(:order, increment_id: '1744', store_id: @veeqo_store.id, store_order_id: '331856255', veeqo_allocation_id: '246838519')

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end

    it 'Import Split Orders' do
      create(:order, increment_id: '1744', store_id: @veeqo_store.id, store_order_id: '331856255', veeqo_allocation_id: nil)

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end

    it 'Import Orders When Product Source as Shopify Store without mock response' do
      shopify_store = create(:store, name: 'Shopify', status: true, store_type: 'Shopify',
                                     inventory_warehouse: @inv_wh, on_demand_import: true)
      create(:shopify_credential, store_id: shopify_store.id, shop_name: 'test_shop')
      @veeqo_store.veeqo_credential.update(use_shopify_as_product_source_switch: true,
                                           product_source_shopify_store_id: shopify_store.id)

      allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:execute_grahpql_query).and_return(mock_without_response)

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(0)
      expect(Product.count).to eq(0)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end

    it 'Import Orders When Product Source as Shopify Store with mock response' do
      shopify_store = create(:store, name: 'Shopify', status: true, store_type: 'Shopify',
                                     inventory_warehouse: @inv_wh, on_demand_import: true)
      create(:shopify_credential, store_id: shopify_store.id, shop_name: 'test_shop')
      @veeqo_store.veeqo_credential.update(use_shopify_as_product_source_switch: true,
                                           product_source_shopify_store_id: shopify_store.id)

      allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:execute_grahpql_query).and_return(mock_response)
      allow_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:product).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_product_for_veeqo_order_import.yaml'))))

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(1)
      expect(Product.count).to eq(1)

      veeqo_import_item = ImportItem.find_by_store_id(@veeqo_store.id)
      expect(veeqo_import_item.status).to eq('completed')
    end
  end

  describe 'Shipstation API 2 Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @ss_store = Store.create(name: 'Shipstation API 2', status: true, store_type: 'Shipstation API 2',
                               inventory_warehouse: InventoryWarehouse.last, on_demand_import_v2: true, regular_import_v2: true, troubleshooter_option: true)
      @ss_store_credential = ShipstationRestCredential.create(api_key: 'shipstationapiv2shipstationapiv2',
                                                              api_secret: 'shipstationapiv2shipstationapiv2', store_id: @ss_store.id, shall_import_awaiting_shipment: false, shall_import_shipped: true, warehouse_location_update: false, shall_import_customer_notes: true, shall_import_internal_notes: true, regular_import_range: 3, gen_barcode_from_sku: true, shall_import_pending_fulfillment: false, use_chrome_extention: false, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: true, allow_duplicate_order: true, tag_import_option: true, bulk_import: false, order_import_range_days: 30, import_tracking_info: true, import_shipped_having_tracking: true)
    end

    it 'Import Orders without aliasing' do
      @tenant.update(loggly_shipstation_imports: true)
      ScanPackSetting.first.update(replace_gp_code: false)
      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_response_from_shipstation).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_shipments).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_shipment_order.yaml'))))
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:remove_gp_tags_from_ss).and_return(true)
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:should_fetch_shipments?).and_return(true)
      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(4)

      ss_import_item = ImportItem.find_by_store_id(@ss_store.id)
      expect(ss_import_item.status).to eq('completed')
    end

    it 'Import Orders' do
      ScanPackSetting.first.update(replace_gp_code: true)
      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_response_from_shipstation).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_shipments).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_shipment_order.yaml'))))
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:remove_gp_tags_from_ss).and_return(true)
      allow_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:should_fetch_shipments?).and_return(true)
      expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_all_tags_list).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_order_tags.yaml'))))

      request.accept = 'application/json'

      $redis.del("importing_orders_#{Apartment::Tenant.current}")

      get :import_all
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)
      expect(OrderTag.count).to be > (1)
      expect(OrderTag.pluck(:name)).to include('GP Imported')

      ss_import_item = ImportItem.find_by_store_id(@ss_store.id)
      expect(ss_import_item.status).to eq('completed')
    end

    it 'SS  Range Import' do
      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_order_response_from_ss).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_shipments).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_shipment_order.yaml'))))

      get :import_for_ss,
          params: { 'store_id' => @ss_store.id, 'days' => '0', 'import_type' => 'range_import', 'import_date' => 'null',
                    'start_date' => DateTime.now.in_time_zone - 2.days, 'end_date' => DateTime.now.in_time_zone, 'order_date_type' => 'modified', 'order_id' => 'null' }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(2)
      expect(Product.count).to eq(2)
    end

    it 'SS Quick Import' do
      expect_any_instance_of(Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew).to receive(:fetch_order_response_from_ss).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_test_order.yaml'))))
      expect_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_shipments).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/ss_shipment_order.yaml'))))
      order = create(:order, increment_id: 'Test SS', store_id: @ss_store.id)

      get :import_for_ss,
          params: { 'store_id' => @ss_store.id, 'days' => '0', 'import_type' => 'quickfix',
                    'import_date' => DateTime.now.in_time_zone, 'start_date' => 'null', 'end_date' => 'null', 'order_date_type' => 'null', 'order_id' => order.increment_id }
      expect(response.status).to eq(200)
      expect(Order.count).to eq(3)
      expect(Product.count).to eq(2)
    end

    it 'SS Import for single store shows import Cancelled' do
      ImportItem.create(status: 'in_progress', store: @ss_store)

      request.accept = 'application/json'
      get :cancel_import, params: { 'store_id' => @ss_store.id, 'order' => { 'store_id' => @ss_store.id } }
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
      FactoryBot.create(:product_sku, product:, sku: 'PRODUCTTEST')
      FactoryBot.create(:product_barcode, product:, barcode: 'PRODUCTTEST')

      order = FactoryBot.create(:order, increment_id: '100', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)

      order = FactoryBot.create(:order, increment_id: '10', status: 'awaiting', tracking_num: '100', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)

      order = FactoryBot.create(:order, increment_id: 'T', status: 'awaiting', tracking_num: '9400111298370613423837',
                                        store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)

      order = FactoryBot.create(:order, increment_id: 'TR', status: 'awaiting', tracking_num: '12345', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)

      order = FactoryBot.create(:order, increment_id: '1234512345', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)

      order = FactoryBot.create(:order, increment_id: 'TRA', status: 'awaiting', tracking_num: '1234512345',
                                        store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order:,
                                     name: product.name)
    end

    it 'find order search by tracking number ending' do
      post :search, params: { search: '613423837', order: 'DESC', limit: 20, offset: 0, product_search_toggle: true }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['orders'].first['ordernum']).to eq('T')
      expect(result['orders'].first['tracking_num']).to eq('9400111298370613423837')
    end

    it 'find order search without toggle' do
      post :search, params: { search: '837', order: 'DESC', limit: 20, offset: 0, product_search_toggle: false }

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
        image = {
          image: 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII', content_type: 'image/png', original_filename: 'sample_image.png'
        }
        file_name = "packing_cams/#{SecureRandom.random_number(20_000)}_#{Time.current.strftime('%d_%b_%Y_%I__%M_%p')}_#{current_tenant}_#{order.id}_" + image[:original_filename].delete('#')
        GroovS3.create_image(current_tenant, file_name, image[:image], image[:content_type])
        url = ENV['S3_BASE_URL'] + '/' + current_tenant + '/image/' + file_name
        packing_cam = order.packing_cams.create(url:, user: @user, username: @user&.username)

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

        params = { order_number: order.increment_id,
                   ss_label_data: {
                     shipping_address: { name: 'sigma tester', address1: '781 WARWICK AVE', address2: nil, state: 'RI',
                                         postal_code: '02888-2601', city: 'WARWICKs', country: 'US' }, dimensions: { units: 'centimeters', length: 14, width: 65, height: 43 }, weight: { value: 13, units: 'pounds' }
                   } }

        post(:update_ss_label_order_data, params:)
        expect(response.status).to eq(200)
        expect(order.reload.label_data['weight']['value']).to eq '13'
      end
    end

    it 'Send packing cam email' do
      @tenant.update(packing_cam: true)
      ScanPackSetting.last.update(packing_cam_enabled: true, email_customer_option: true)
      order = FactoryBot.create :order, store_id: @store.id

      post :send_packing_cam_email, params: { id: order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end

    it 'Print Packing Slip 4 x 4' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester', username: 'packing_slip_tester1', packing_slip_size: '4 x 4')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip 4 x 2' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester', username: 'packing_slip_tester2', packing_slip_size: '4 x 2')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip Custom 4 x 6' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester', username: 'packing_slip_tester2',
                                       packing_slip_size: 'Custom 4 x 6')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip' do
      order = FactoryBot.create :order, store_id: @store.id
      @user = FactoryBot.create(:user, name: 'Tester', username: 'packing_slip_tester1', packing_slip_size: '8.5 x 11')

      post :generate_packing_slip, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Print Packing Slip wothout order' do
      post :generate_packing_slip, params: { orderArray: [] }
      expect(response.status).to eq(200)
      res = JSON.parse(response.body)
      expect(res['status']).to eq(false)
      expect(res['messages']).to eq(['No orders selected'])
    end

    it 'Print all Packing Slip' do
      order = FactoryBot.create :order, store_id: @store.id

      get :generate_all_packing_slip,
          params: { sort: '', order: 'DESC', filter: 'awaiting', search: '', inverted: false, limit: 20, offset: 0, status: '',
                    reallocate_inventory: false, product_search_toggle: 'false' }
      expect(response.status).to eq(200)

      get :generate_all_packing_slip,
          params: { sort: '', order: 'DESC', filter: 'awaiting,scanned', search: '', inverted: false, limit: 20, offset: 0,
                    status: '', reallocate_inventory: false, product_search_toggle: 'false' }
      expect(response.status).to eq(200)

      get :generate_all_packing_slip,
          params: { sort: '', order: 'DESC', filter: 'awaiting', search: '', inverted: false, limit: 20, select_all: 'false',
                    offset: 0, status: '', reallocate_inventory: false, product_search_toggle: 'false' }
      expect(response.status).to eq(200)
    end

    it 'Add item to order if product exists' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')

      post :add_item_to_order, params: { id: order.id, productids: [product.id.to_s] }
      expect(response.status).to eq(200)

      post :add_item_to_order, params: { id: order.id, productids: [product.id.to_s], add_to_scanned_list: true }
      expect(order.order_items.last.qty).to eq(2)
      expect(order.order_items.last.scanned_qty).to eq(1)
    end

    it 'remove item qty from order for Kit' do
      order = FactoryBot.create :order, store_id: @store.id
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                               store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-BLACK-L', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductKitSkus.create(product_id: product.id, option_product_id: product2.id, qty: 1, packing_order: 50)

      order_item = OrderItem.create(sku: nil, qty: 10, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'partially_scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 2)
      kit.product_kit_skuss << productkitsku
      ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
      order_item_kit_product = OrderItemKitProduct.create(order_item_id: order_item.id,
                                                          product_kit_skus_id: productkitsku.id, scanned_status: 'partially_scanned', scanned_qty: 1)

      post :remove_item_qty_from_order, params: { orderitem: [order_item.id], status: '' }
      productkitsku.reload
      expect(response.status).to eq(200)
      expect(productkitsku.qty).to eq(1)
    end

    it 'remove item qty from order' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1', product_type: 'individual')
      order_item = OrderItem.create(sku: nil, qty: 10, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'partially_scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      post :remove_item_qty_from_order, params: { orderitem: [order_item.id], status: '' }
      expect(response.status).to eq(200)
    end

    it 'Add item to order if product is kit' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
      kit.product_kit_skuss << productkitsku
      ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: productkitsku.id,
                                 scanned_status: 'scanned', scanned_qty: 1)

      post :add_item_to_order, params: { id: order.id, productids: [product.id.to_s] }
      expect(response.status).to eq(200)
      expect(order.order_items.last.qty).to eq(2)
      expect(order.order_items.last.scanned_status).to eq('partially_scanned')
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
      store = FactoryBot.create(:store, name: 'ss_store', store_type: 'Shipstation API 2', inventory_warehouse: @inv_wh,
                                        status: true)
      ss_credential = FactoryBot.create(:shipstation_rest_credential, store_id: store.id)
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                               store_id: store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      box = Box.create(name: 'Box 1', order_id: order.id)
      OrderItemBox.create(box_id: box.id, order_item_id: order_item.id, item_qty: 1, kit_id: nil)
      params = { id: order.id }

      get(:show, params:)
      expect(response.status).to eq(200)
    end

    it 'Get Real Time Rates' do
      allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:list_carriers).and_return( double(body: File.read(Rails.root.join('spec/fixtures/files/ss_list_carriers.json'))))
      allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:get_ss_label_rates).and_return( double(body: File.read(Rails.root.join('spec/fixtures/files/ss_label_rates.json')), ok?: true))
      allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:list_services).and_return( double(body: File.read(Rails.root.join('spec/fixtures/files/ss_list_services.json'))))
      allow_any_instance_of(Groovepacker::ShipstationRuby::Rest::Client).to receive(:list_packages).and_return( double(body: File.read(Rails.root.join('spec/fixtures/files/ss_list_packages.json'))))

      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'ss_store', store_type: 'Shipstation API 2', inventory_warehouse: @inv_wh, status: true)
      ss_credential = FactoryBot.create(:shipstation_rest_credential, store_id: store.id)
      order = FactoryBot.create(:order, increment_id: '113-5739664-0875452', store_id: @store.id, store_order_id: '887321785')
      params = { credential_id: ss_credential.id, carrier_code: '', post_data: { weight: '10', fromPostalCode: '10005', toState: 'South Carolina', toCountry: 'US', toPostalCode: '25918-2743', confirmation_code: 'none' } }

      post(:get_realtime_rates, params:)
      expect(response.status).to eq(200)
    end

    it 'Record Exception' do
      order = FactoryBot.create :order, store_id: @store.id

      request.accept = 'application/json'

      post :record_exception, params: { id: order.id, reason: '' }
      expect(response.status).to eq(200)
    end

    it 'cancel_tagging_jobs should be working' do
      request.accept = 'application/json'

      post :cancel_tagging_jobs
      expect(response.status).to eq(200)
    end

    it 'Saved By Pass Log' do
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      product_sku = FactoryBot.create(:product_sku, product:, sku: 'PRODUCT1')
      request.accept = 'application/json'

      post :save_by_passed_log, params: { id: order.id, sku: product_sku.sku }
      expect(response.status).to eq(200)
    end

    it 'Generate pick list' do
      order = FactoryBot.create :order, store_id: @store.id
      request.accept = 'application/json'

      post :generate_pick_list, params: { orderArray: [{ id: order.id }] }
      expect(response.status).to eq(200)
    end

    it 'Generate pick list without order' do
      request.accept = 'application/json'

      post :generate_pick_list, params: { orderArray: [] }
      expect(response.status).to eq(200)
      res = JSON.parse(response.body)
      expect(res['status']).to eq(false)
      expect(res['messages']).to eq(['No orders selected'])
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
      @user = FactoryBot.create(:user, name: 'Manager User', username: 'Order_tester', role: user_role,
                                       confirmation_code: 123_412)
      request.accept = 'application/json'

      post :change_orders_status, params: { id: @user.id, confirmation_code: @user.confirmation_code }
      expect(response.status).to eq(200)
    end

    it 'Change Orders Status with multi status' do
      user_role = FactoryBot.create(:role, name: 'tester_role1', add_edit_users: true, change_order_status: true)
      @user = FactoryBot.create(:user, name: 'Manager User', username: 'Order_tester', role: user_role,
                                       confirmation_code: 123_412)
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'store', store_type: 'system', inventory_warehouse: @inv_wh, status: true)
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                               store_id: store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'

      post :change_orders_status, as: :json,
                                  params: { id: @user.id, confirmation_code: @user.confirmation_code, 'filter' => 'awaiting, scanned', 'inverted' => false, 'limit' => 20, 'offset' => 0, 'order' => 'DESC', 'orderArray' => [{ 'id' => order.id }], 'product_search_toggle' => true, 'reallocate_inventory' => false, 'search' => '', 'select_all' => true, 'sort' => '', 'status' => 'awaiting', 'pull_inv' => true, 'on_ex' => 'on GPX' }
      expect(response.status).to eq(200)
    end

    it 'Change Orders Status with filters' do
      user_role = FactoryBot.create(:role, name: 'tester_role1', add_edit_users: true, change_order_status: true)
      @user = FactoryBot.create(:user, name: 'Manager User', username: 'Order_tester', role: user_role,
                                       confirmation_code: 123_412)
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'store', store_type: 'system', inventory_warehouse: @inv_wh, status: true)
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                               store_id: store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'

      filterValue = [
        { name: 'OrderNumber', operator: 'contains', type: 'string', value: '123' },
        { name: 'Store', operator: 'contains', type: 'string', value: '123' },
        { name: 'Notes', operator: 'contains', type: 'string', value: '123' },
        { name: 'OrderDate', operator: 'inrange', type: 'date', value: { start: '12-2-2022', end: '12-2-2022' } },
        { name: 'Items', operator: 'inrange', type: 'number', value: { start: 1, end: 2 } },
        { name: 'Recipient', operator: 'contains', type: 'string', value: '123' },
        { name: 'Status', operator: 'eq', type: 'string', value: ['Awaiting'] },
        { name: 'Status', operator: 'eq', type: 'string', value: 'Awaiting' },
        { name: 'customFieldOne', operator: 'startsWith', type: 'string', value: '123' },
        { name: 'customFieldTwo', operator: 'endsWith', type: 'string', value: '123' },
        { name: 'trackingNumber', operator: 'contains', type: 'string', value: '123' },
        { name: 'country', operator: 'contains', type: 'string', value: '123' },
        { name: 'city', operator: 'contains', type: 'string', value: '123' },
        { name: 'email', operator: 'noContains', type: 'string', value: '123' },
        { name: 'tote', operator: 'noContains', type: 'string', value: '123' }
      ]

      post :change_orders_status, as: :json, params: {id: @user.id, confirmation_code: @user.confirmation_code, 'filter'=>'awaiting, scanned', 'inverted'=>false, 'limit'=>20, 'offset'=>0, 'order'=>'DESC', 'orderArray'=>[{'id'=>order.id}], 'product_search_toggle'=>true, 'reallocate_inventory'=>false, 'search'=>'', 'select_all'=>true, 'sort'=>'', 'status'=>'awaiting', 'pull_inv'=>true, 'on_ex'=>'on GPX',  'filters' => filterValue.to_json, tags_name: 'Contains Inactive', filterIncludedTags: false }
      expect(response.status).to eq(200)

      post :change_orders_status, as: :json,
                                  params: { id: @user.id, confirmation_code: @user.confirmation_code, 'filter' => 'awaiting, scanned', 'inverted' => false, 'limit' => 20, 'offset' => 0, 'order' => 'DESC', 'orderArray' => [{ 'id' => order.id }], 'product_search_toggle' => true, 'reallocate_inventory' => false, 'search' => '', 'select_all' => true, 'sort' => '', 'status' => 'awaiting', 'pull_inv' => true, 'on_ex' => 'on GPX', 'filters' => filterValue.to_json, 'unselected' => 'C000209814-B(Duplicate-2)' }
      expect(response.status).to eq(200)
    end

    it 'Change Order Status for GPX with Pull Inv' do
      user_role = FactoryBot.create(:role, name: 'tester_role1', add_edit_users: true, change_order_status: true)
      @user = FactoryBot.create(:user, name: 'Manager User', username: 'Order_tester', role: user_role,
                                       confirmation_code: 123_412)
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'store', store_type: 'system', inventory_warehouse: @inv_wh, status: true)
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                               store_id: store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      GeneralSetting.last.update(inventory_tracking: true)
      request.accept = 'application/json'

      post :change_orders_status, as: :json,
                                  params: { 'id' => @user.id, 'confirmation_code' => @user.confirmation_code, 'filter' => 'all', 'inverted' => false, 'limit' => 20, 'offset' => 0, 'order' => 'DESC', 'orderArray' => [{ 'id' => order.id }], 'product_search_toggle' => true, 'reallocate_inventory' => false, 'search' => '', 'select_all' => false, 'sort' => '', 'status' => 'awaiting', 'pull_inv' => true, 'on_ex' => 'on GPX' }
      expect(response.status).to eq(200)
    end

    it 'Import Cancelled' do
      user = User.last
      ss_store = Store.where(store_type: 'CSV').last
      OrderImportSummary.create(status: 'in_progress', user_id: user.id, import_summary_type: 'import_orders',
                                display_summary: true)

      allow(ElixirApi::Processor::CSV::OrdersToXML).to receive(:cancel_import).and_return(true)

      request.accept = 'application/json'
      get :cancel_import, params: { store_id: ss_store.id, order: { store_id: ss_store.id } }
      expect(response.status).to eq(200)
    end

    it 'App Orders params' do
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-BLACK-L', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductKitSkus.create(product_id: product1.id, option_product_id: product2.id, qty: 1, packing_order: 50)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'

      post :index,
           params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0',
                     'product_search_toggle' => 'undefined', 'app' => true }
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)

      post :index,
           params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0',
                     'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1' }
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)
    end

    it 'sorted and filtered data' do
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-BLACK-L', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductKitSkus.create(product_id: product1.id, option_product_id: product2.id, qty: 1, packing_order: 50)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'
      filterValue = [
        { name: 'OrderNumber', operator: 'contains', type: 'string', value: '123' },
        { name: 'Store', operator: 'contains', type: 'string', value: '123' },
        { name: 'Notes', operator: 'contains', type: 'string', value: '123' },
        { name: 'OrderDate', operator: 'notinrange', type: 'date', value: { start: '12-2-2022', end: '12-2-2022' } },
        { name: 'Items', operator: 'inrange', type: 'number', value: { start: 1, end: 2 } },
        { name: 'Recipient', operator: 'contains', type: 'string', value: '123' },
        { name: 'Status', operator: 'eq', type: 'string', value: ['Awaiting'] },
        { name: 'Status', operator: 'eq', type: 'string', value: 'Awaiting' },
        { name: 'customFieldOne', operator: 'startsWith', type: 'string', value: '123' },
        { name: 'customFieldTwo', operator: 'endsWith', type: 'string', value: '123' },
        { name: 'trackingNumber', operator: 'contains', type: 'string', value: '123' },
        { name: 'country', operator: 'contains', type: 'string', value: '123' },
        { name: 'city', operator: 'contains', type: 'string', value: '123' },
        { name: 'email', operator: 'noContains', type: 'string', value: '123' },
        { name: 'tote', operator: 'noContains', type: 'string', value: '123' }
      ]
      post :sorted_and_filtered_data, params: {
        'filter' => 'awaiting',
        'shouldFilter' => 'true',
        'sort' => '',
        'order' => 'DESC',
        'limit' => '20',
        'offset' => '0',
        'product_search_toggle' => 'undefined',
        'app' => true,
        'filters' => filterValue.to_json,
        'dateValue' => 'today'
      }
      expect(response.status).to eq(200)

      # expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      # expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)
      post :sorted_and_filtered_data, params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json, search: '123',  'dateValue' => 'this_week' }
      expect(response.status).to eq(200)

      post :sorted_and_filtered_data, params: { 'filter' => 'all', 'sort' => '', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json,  'dateValue' => 'last_week'}
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)
    end

    it 'sorted data' do
      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil,
                           customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-BLACK-L', product_type: '',
                                store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductKitSkus.create(product_id: product1.id, option_product_id: product2.id, qty: 1, packing_order: 50)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                     name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)

      request.accept = 'application/json'
      filterValue = [
        { name: 'OrderNumber', operator: 'contains', type: 'string', value: '' },
        { name: 'Store', operator: 'contains', type: 'string', value: '' },
        { name: 'Notes', operator: 'contains', type: 'string', value: '' },
        { name: 'OrderDate', operator: 'notinrange', type: 'date', value: { start: '', end: '' } },
        { name: 'Items', operator: 'inrange', type: 'number', value: { start: '', end: '' } },
        { name: 'Recipient', operator: 'contains', type: 'string', value: '' },
        { name: 'Status', operator: 'eq', type: 'string', value: ['Awaiting'] },
        { name: 'customFieldOne', operator: 'startsWith', type: 'string', value: '' },
        { name: 'customFieldTwo', operator: 'endsWith', type: 'string', value: '' },
        { name: 'trackingNumber', operator: 'contains', type: 'string', value: '' },
        { name: 'country', operator: 'contains', type: 'string', value: '' },
        { name: 'city', operator: 'contains', type: 'string', value: '' },
        { name: 'email', operator: 'noContains', type: 'string', value: '' },
        { name: 'tote', operator: 'noContains', type: 'string', value: '' }
      ]
      post :sorted_and_filtered_data, params: {
        'filter' => 'awaiting',
        'shouldFilter' => 'true',
        'sort' => '',
        'order' => 'DESC',
        'limit' => '20',
        'offset' => '0',
        'product_search_toggle' => 'undefined',
        'app' => true,
        'filters' => filterValue.to_json,
        'dateValue' => 'this_month',
        'dateRange' => {"start_date":"07-01-2024","end_date":"07-07-2024"}
      }
      expect(response.status).to eq(200)

      post :sorted_and_filtered_data, params: { 'filter' => 'all', 'sort' => 'itemslength', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json, 'dateValue' => 'last_month' }
      expect(response.status).to eq(200)

      post :sorted_and_filtered_data, params: { 'filter' => 'all', 'sort' => 'store_name', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json, 'dateValue' => '7' }
      expect(response.status).to eq(200)

      post :sorted_and_filtered_data, params: { 'filter' => 'all', 'sort' => 'user', 'order' => 'DESC', 'limit' => '20', 'offset' => '0', 'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json, 'dateValue' => '7' }
      expect(response.status).to eq(200)

      post :change_orders_status, as: :json, params: {id: @user.id, confirmation_code: @user.confirmation_code, 'filter'=>'awaiting, scanned', 'inverted'=>false, 'limit'=>20, 'offset'=>0, 'order'=>'DESC', 'orderArray'=>[{'id'=>order.id}], 'product_search_toggle'=>true, 'reallocate_inventory'=>false, 'search'=>'', 'select_all'=>true, 'sort'=>'', 'status'=>'awaiting', 'pull_inv'=>true, 'on_ex'=>'on GPX',  'filters' => filterValue.to_json, tags_name: 'Contains Inactive', filterIncludedTags: false, username: 'Manager User' }
      expect(response.status).to eq(200)

      post :sorted_and_filtered_data,
           params: { 'filter' => 'all', 'sort' => 'tote', 'order' => 'DESC', 'limit' => '20', 'offset' => '0',
                     'product_search_toggle' => 'undefined', 'app' => true, 'count' => '1', 'filters' => filterValue.to_json }
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)['orders_count']['scanned']).to eq(1)
      expect(JSON.parse(response.body)['orders_count']['all']).to eq(1)
    end
  end

  describe '#check_orders_tags' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    filterValue = [
        { name: 'OrderNumber', operator: 'contains', type: 'string', value: '123'},
        { name: 'Store', operator: 'contains', type: 'string', value: '123'},
        { name: 'Notes', operator: 'contains', type: 'string', value: '123'},
        { name: 'OrderDate', operator: 'inrange', type: 'date', value: {start: '12-2-2022', end: '12-2-2022'}},
        { name: 'Items', operator: 'inrange', type: 'number', value: {start: 1, end: 2}},
        { name: 'Recipient', operator: 'contains', type: 'string', value: '123'},
        { name: 'Status', operator: 'eq', type: 'string', value: ['Awaiting']},
        { name: 'Status', operator: 'eq', type: 'string', value: 'Awaiting'},
        { name: 'customFieldOne', operator: 'startsWith', type: 'string', value: '123'},
        { name: 'customFieldTwo', operator: 'endsWith', type: 'string', value: '123'},
        { name: 'trackingNumber', operator: 'contains', type: 'string', value: '123'},
        { name: 'country', operator: 'contains', type: 'string', value: '123'},
        { name: 'city', operator: 'contains', type: 'string', value: '123'},
        { name: 'email', operator: 'noContains', type: 'string', value: '123'},
        { name: 'tote', operator: 'noContains', type: 'string', value: '123'},
      ]

    emptyfilterValue = [
        { name: 'OrderNumber', operator: 'contains', type: 'string', value: ''},
        { name: 'Store', operator: 'contains', type: 'string', value: ''},
        { name: 'Notes', operator: 'contains', type: 'string', value: ''},
        { name: 'OrderDate', operator: 'inrange', type: 'date', value: {}},
        { name: 'Items', operator: 'inrange', type: 'number', value: {}},
        { name: 'Recipient', operator: 'contains', type: 'string', value: ''},
        { name: 'Status', operator: 'eq', type: 'string', value: []},
        { name: 'Status', operator: 'eq', type: 'string', value: ''},
        { name: 'customFieldOne', operator: 'startsWith', type: 'string', value: ''},
        { name: 'customFieldTwo', operator: 'endsWith', type: 'string', value: ''},
        { name: 'trackingNumber', operator: 'contains', type: 'string', value: ''},
        { name: 'country', operator: 'contains', type: 'string', value: ''},
        { name: 'city', operator: 'contains', type: 'string', value: ''},
        { name: 'email', operator: 'noContains', type: 'string', value: ''},
        { name: 'tote', operator: 'noContains', type: 'string', value: ''},
      ]

    tags = "[{\"id\":1,\"name\":\"Contains New\",\"color\":\"#FF0000\",\"mark_place\":\"0\",\"created_at\":\"2023-12-27T17:00:44.000-05:00\",\"updated_at\":\"2023-12-27T17:00:44.000-05:00\",\"predefined\":true,\"groovepacker_tag_origin\":null,\"source_id\":null},{\"id\":2,\"name\":\"Contains Inactive\",\"color\":\"#00FF00\",\"mark_place\":\"0\",\"created_at\":\"2023-12-27T17:00:44.000-05:00\",\"updated_at\":\"2023-12-27T17:00:44.000-05:00\",\"predefined\":true,\"groovepacker_tag_origin\":null,\"source_id\":null},{\"id\":3,\"name\":\"Manual Hold\",\"color\":\"#0000FF\",\"mark_place\":\"0\",\"created_at\":\"2023-12-27T17:00:44.000-05:00\",\"updated_at\":\"2023-12-27T17:00:44.000-05:00\",\"predefined\":true,\"groovepacker_tag_origin\":null,\"source_id\":null},{\"id\":4,\"name\":\"Simple Bundles - Bundle O\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-05-19T09:10:12.000-04:00\",\"updated_at\":\"2024-05-19T09:10:12.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":73,\"name\":\"Loox - Photo/Video Review\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-05-19T09:20:18.000-04:00\",\"updated_at\":\"2024-05-19T09:20:18.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":261,\"name\":\"contentcreator\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-05-21T21:10:11.000-04:00\",\"updated_at\":\"2024-05-21T21:10:11.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":262,\"name\":\"influencer\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-05-21T21:10:11.000-04:00\",\"updated_at\":\"2024-05-21T21:10:11.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":null,\"source_id\":null},{\"id\":263,\"name\":\"Exchange\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-05-26T21:50:09.000-04:00\",\"updated_at\":\"2024-05-26T21:50:09.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":264,\"name\":\"Simple Bundles - Bundle Order\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-06-02T18:00:18.000-04:00\",\"updated_at\":\"2024-06-02T18:00:18.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":265,\"name\":\"Loox - Photo/Video Review Discount\",\"color\":\"#95BF47\",\"mark_place\":\"0\",\"created_at\":\"2024-06-02T20:00:22.000-04:00\",\"updated_at\":\"2024-06-02T20:00:22.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"SHOPIFY\",\"source_id\":null},{\"id\":266,\"name\":\"GP Imported\",\"color\":\"#008000\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:05:54.000-04:00\",\"updated_at\":\"2024-06-14T05:05:54.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"48785\"},{\"id\":267,\"name\":\"GP SCANNED\",\"color\":\"#B7B7B7\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:05:54.000-04:00\",\"updated_at\":\"2024-06-14T05:05:54.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"116428\"},{\"id\":268,\"name\":\"GPA-stickles\",\"color\":\"#FF9900\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:09:33.000-04:00\",\"updated_at\":\"2024-06-14T05:09:33.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"126725\"},{\"id\":269,\"name\":\"SSTAG-001\",\"color\":\"#00FFFF\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:18:17.000-04:00\",\"updated_at\":\"2024-06-14T05:18:17.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"128275\"},{\"id\":270,\"name\":\"SS-TAG-002\",\"color\":\"#FFFF00\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:18:17.000-04:00\",\"updated_at\":\"2024-06-14T05:18:17.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"128276\"},{\"id\":271,\"name\":\"SS-TAG-003\",\"color\":\"#FF00FF\",\"mark_place\":\"0\",\"created_at\":\"2024-06-14T05:18:17.000-04:00\",\"updated_at\":\"2024-06-14T05:18:17.000-04:00\",\"predefined\":false,\"groovepacker_tag_origin\":\"STATION\",\"source_id\":\"128277\"}]"

    let!(:tag1) { OrderTag.create(name: 'Tag1') }
    let!(:tag2) { OrderTag.create(name: 'Tag2') }
    let!(:tag3) { OrderTag.create(name: 'Tag3') }

    it 'tag update should be working' do
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store,name: "store", store_type: "system",inventory_warehouse: @inv_wh, status: true)
      order =
        Order.create(
          increment_id: '9151',
          order_placed_time: Time.current,
          store_id: store.id,
          firstname: 'BIKE',
          lastname: 'ACTIONGmbH',
          email: 'east@raceface.com',
          address_1: 'WEISKIRCHER STR. 102',
          city: 'RODGAU',
          postcode: '63110',
          country: 'GERMANY',
          status: 'scanned',
          scanned_on: Time.current,
          packing_user_id: 2,
          total_scan_time: 1720,
          total_scan_count: 20,
          packing_score: 14
        )

      orderArray = '[{"id":9151}, {"id":9152}, {"id":17938}, {"id":17964}, {"id":17983}, {"id":18238}]'

      request.accept = 'application/json'
      get :check_orders_tags, params: {filter: 'all', tags: tags, filters: filterValue.to_json, orderArray: orderArray, select_all: true }

      expect(response).to have_http_status(:success)
      result = JSON.parse(response.body)
      expect(result['tags']['partially_present']).to be_empty

      post :add_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      post :remove_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      102.times do |i|
        Order.create(
          increment_id: (9151 + i).to_s,
          order_placed_time: Time.current,
          store_id: store.id,
          firstname: 'BIKE',
          lastname: 'ACTIONGmbH',
          email: "east+#{i}@raceface.com", # Unique email for each order
          address_1: 'WEISKIRCHER STR. 102',
          city: 'RODGAU',
          postcode: '63110',
          country: 'GERMANY',
          status: 'scanned',
          scanned_on: Time.current,
          packing_user_id: 2,
          total_scan_time: 1720,
          total_scan_count: 20,
          packing_score: 14
        )
      end
      allow($redis).to receive(:get).and_return("true")
      post :add_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      post :remove_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end

    it 'tag update should be working with bulk orders' do
      @inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store,name: "store", store_type: "system",inventory_warehouse: @inv_wh, status: true)
      order =
        Order.create(
          increment_id: '9151',
          order_placed_time: Time.current,
          store_id: store.id,
          firstname: 'BIKE',
          lastname: 'ACTIONGmbH',
          email: 'east@raceface.com',
          address_1: 'WEISKIRCHER STR. 102',
          city: 'RODGAU',
          postcode: '63110',
          country: 'GERMANY',
          status: 'scanned',
          scanned_on: Time.current,
          packing_user_id: 2,
          total_scan_time: 1720,
          total_scan_count: 20,
          packing_score: 14
        )

      orderArray = '[{"id":9151}, {"id":9152}, {"id":17938}, {"id":17964}, {"id":17983}, {"id":18238}]'

      request.accept = 'application/json'
      get :check_orders_tags, params: {filter: 'all', tags: tags, filters: filterValue.to_json, orderArray: orderArray, select_all: true }

      expect(response).to have_http_status(:success)
      result = JSON.parse(response.body)
      expect(result['tags']['partially_present']).to be_empty

      post :add_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      post :remove_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      1002.times do |i|
        Order.create(
          increment_id: (9151 + i).to_s,
          order_placed_time: Time.current,
          store_id: store.id,
          firstname: 'BIKE',
          lastname: 'ACTIONGmbH',
          email: "east+#{i}@raceface.com", # Unique email for each order
          address_1: 'WEISKIRCHER STR. 102',
          city: 'RODGAU',
          postcode: '63110',
          country: 'GERMANY',
          status: 'scanned',
          scanned_on: Time.current,
          packing_user_id: 2,
          total_scan_time: 1720,
          total_scan_count: 20,
          packing_score: 14
        )
      end
      allow($redis).to receive(:get).and_return("true")
      post :add_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)

      post :remove_tags, params: {filter: 'all', tag_name: tag1.name,  filters: emptyfilterValue.to_json, orderArray: orderArray, select_all: true }
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end
  end

  describe 'Order Items Export Report' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'When order export items is disabled' do
      @generalsetting
      order = FactoryBot.create :order, store_id: @store.id

      post :order_items_export, as: :json, params:{sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{id: order.id}], product_search_toggle: 'false', export_type: ''}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['messages']).to eq(['Order export items is disabled.'])
    end

    it 'Single order is selected' do
      @generalsetting
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      kit.product_kit_skuss << productkitsku
      ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: productkitsku.id,
                                 scanned_status: 'unscanned', scanned_qty: 0)

      @generalsetting.update_column(:export_items, 'standard_order_export')
      post :order_items_export, as: :json,
                                params: { sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{ id: order.id }], product_search_toggle: 'false' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['filename']).to be_present
    end

    it 'Single order is selected with export type' do
      @generalsetting
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual', name: 'KIT1')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      kit.product_kit_skuss << productkitsku
      ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: productkitsku.id, scanned_status: "unscanned", scanned_qty: 0)

      post :order_items_export, as: :json, params:{sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{id: order.id}], product_search_toggle: 'false', export_type: 'standard_order_export'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['filename']).to be_present
    end

    it 'All orders are selected' do
      @generalsetting
      order = FactoryBot.create :order, store_id: @store.id
      product = FactoryBot.create(:product, name: 'PRODUCT1')
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                    name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      kit.product_kit_skuss << productkitsku
      ProductSku.create(sku: 'PRODUCT90', purpose: nil, product_id: product.id, order: 0)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: productkitsku.id,
                                 scanned_status: 'unscanned', scanned_qty: 0)

      @generalsetting.update_column(:export_items, 'standard_order_export')
      post :order_items_export, as: :json,
                                params: { sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: true, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{ id: order.id }], product_search_toggle: 'false' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
    end

    it 'Order is not selected' do
      post :order_items_export, as: :json,
                                params: { sort: '', order: 'DESC', filter: 'awaiting', search: '', select_all: false, inverted: false, limit: 20, offset: 0, status: '', reallocate_inventory: false, orderArray: [{ id: '' }], product_search_toggle: 'false' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)
      expect(result['messages']).to eq(['No orders selected'])
    end
  end
end
