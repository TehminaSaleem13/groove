# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderImportSummariesController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user = FactoryBot.create(:user, username: 'scan_pack_spec_user', name: 'Scan Pack user', role: Role.find_by_name('Scan & Pack User'))
    access_restriction = FactoryBot.create(:access_restriction)
    inv_wh = FactoryBot.create(:inventory_warehouse, name: 'scan_pack_inventory_warehouse')
    @store = FactoryBot.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    csv_mapping = FactoryBot.create(:csv_mapping, store_id: @store.id)
  end

  describe 'Order Import Summary' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    let(:ss_store) { Store.create(name: 'Shipstation', status: true, store_type: 'Shipstation API 2', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true) }
    let(:se_store) { Store.create(name: 'ShippingEasy', status: true, store_type: 'ShippingEasy', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true) }
    let(:sp_store) { Store.create(name: 'Shippo', status: true, store_type: 'Shippo', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true) }
    let(:shopify_store) { Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      ss_store.create_shipstation_rest_credential(api_key: '14ccf1296c2043cb9076b90953b7ea9c', api_secret: '26fc8ff9f7a7411180d2960eb838e2ca', last_imported_at: nil, shall_import_awaiting_shipment: true, shall_import_shipped: false, warehouse_location_update: false, shall_import_customer_notes: true, shall_import_internal_notes: true, regular_import_range: 3, gen_barcode_from_sku: false, shall_import_pending_fulfillment: false, quick_import_last_modified: nil, use_chrome_extention: true, switch_back_button: false, auto_click_create_label: false, download_ss_image: false, return_to_order: false, import_upc: false, allow_duplicate_order: false, tag_import_option: false, bulk_import: false, order_import_range_days: 14, quick_import_last_modified_v2: '2021-04-22 22:53:15', import_tracking_info: false, last_location_push: nil, use_api_create_label: true, postcode: '', label_shortcuts: { 'w' => 'weight', nil => nil, 'd' => 'USPS Parcel Select Ground - Package', '5' => 'Print Label' }, disabled_carriers: ['ups_walleted'], disabled_rates: {}, skip_ss_label_confirmation: true)

      se_store.create_shipping_easy_credential(store_id: se_store.id, api_key: 'apikeyapikeyapikeyapikeyapikeyse', api_secret: 'apisecretapisecretapisecretapisecretapisecretapisecretapisecrets', import_ready_for_shipment: false, import_shipped: true, gen_barcode_from_sku: false, popup_shipping_label: false, ready_to_ship: true, import_upc: true, allow_duplicate_id: true)

      sp_store.create_shippo_credential(store_id: sp_store.id, api_key: 'shippo_test_6cf0a208229f428d9e913de45f83f849eb28d7d3', api_version: '2018-02-08')
      
      shopify_store.create_shopify_credential(store_id: shopify_store.id, shop_name: 'gpjune4', access_token: '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', shopify_status: 'open')
    end

    it 'gets last modified' do
      # For SS
      get :get_last_modified, params: { store_id: ss_store.id }
      expect(response.status).to eq(200)

      # For SE
      get :get_last_modified, params: { store_id: se_store.id }
      expect(response.status).to eq(200)

      # For SP
      get :get_last_modified, params: { store_id: sp_store.id }
      expect(response.status).to eq(200)

      get :get_last_modified, params: { store_id: shopify_store.id }
      expect(response.status).to eq(200)
    end

    it 'downloads summary details' do
      # For SS
      get :download_summary_details, params: { store_id: ss_store.id }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).should_not be_nil
    end

    it 'Fix Imported at' do
      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'bc_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'bc_store', store_type: 'BigCommerce', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'se_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'se_store', store_type: 'ShippingEasy', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'ss_store', store_type: 'Shipstation API 2', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'tp_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'tp_store', store_type: 'Teapplix', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'mg_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'mg_store', store_type: 'Magento', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'sp_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'sp_store', store_type: 'Shopify', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'az_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'az_store', store_type: 'Amazon', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}

      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ma_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'ma_store', store_type: 'Magento API 2', inventory_warehouse: inv_wh, status: true)
      get :fix_imported_at, params: {store_id: store.id}
    end
  end
end
