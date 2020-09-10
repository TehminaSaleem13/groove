# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryGirl.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryGirl.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryGirl.create(:access_restriction)
    inv_wh = FactoryGirl.create(:inventory_warehouse, name: 'csv_inventory_warehouse')
    @store = FactoryGirl.create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true)
    csv_mapping = FactoryGirl.create(:csv_mapping, store_id: @store.id)
  end

  describe 'CSV Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']
    end

    it 'Import CSV Orders' do
      order_import_summary = OrderImportSummary.create(user: User.first, status: 'completed', import_summary_type: 'import_orders', display_summary: false)
      import_item = ImportItem.create(status: 'not_started', store_id: @store.id, order_import_summary_id: order_import_summary.id, import_type: 'regular')

      request.accept = 'application/json'

      expect_any_instance_of(Groovepacker::Orders::Xml::Import).to receive(:check_count_is_equle?).and_return(true)

      (1..4).to_a.each do |order_num|
        post :import_xml, { xml: IO.read(Rails.root.join("spec/fixtures/files/order_import_xml#{order_num}.xml")), import_summary_id: order_import_summary.id, store_id: @store.id, file_name: 'csv_order_import', flag: false }
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
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']

      se_store = Store.create(name: 'ShippingEasy', status: true, store_type: 'ShippingEasy', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true)
      se_store_credentials = ShippingEasyCredential.create(store_id: se_store.id, api_key: 'apikeyapikeyapikeyapikeyapikeyse', api_secret: 'apisecretapisecretapisecretapisecretapisecretapisecretapisecrets', import_ready_for_shipment: false, import_shipped: true, gen_barcode_from_sku: false, popup_shipping_label: false, ready_to_ship: true, import_upc: true, allow_duplicate_id: true)
    end

    it 'Import SE Shipment Handling V2 Orders' do
      se_store = Store.where(store_type: 'ShippingEasy').last

      product = FactoryGirl.create(:product, name: 'PRODUCT1')
      FactoryGirl.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryGirl.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      order1 = FactoryGirl.create(:order, increment_id: 'ORDER1', status: 'awaiting', store: se_store, prime_order_id: '1660160213', store_order_id: '1660160213')
      FactoryGirl.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order1, name: product.name)

      order2 = FactoryGirl.create(:order, increment_id: 'ORDER2', status: 'awaiting', store: se_store, prime_order_id: '1660159733', store_order_id: '1660159733')
      FactoryGirl.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order2, name: product.name)

      order3 = FactoryGirl.create(:order, increment_id: 'ORDER3', status: 'awaiting', store: se_store, prime_order_id: '1660160773', store_order_id: '1660160773')
      FactoryGirl.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order3, name: product.name)

      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/se_shipment_v2.yaml'))))

      request.accept = 'application/json'

      get :import_all
      expect(response.status).to eq(200)

      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.status).to eq('completed')
    end

    it 'Import SE QF Range Orders' do
      expect_any_instance_of(Groovepacker::ShippingEasy::Client).to receive(:fetch_orders).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/SE_test_qf_range_orders.yaml'))))

      request.accept = 'application/json'

      se_store = Store.where(store_type: 'ShippingEasy').last

      get :import_for_ss, { store_id: se_store.id, days: 0, import_type: 'range_import', import_date: 'null', start_date: '2020-08-03 09:00:25', end_date: '2020-08-03 21:00:25', order_date_type: 'modified', order_id: 'null'}
      expect(response.status).to eq(200)
      expect(Order.count).to eq(6)
      se_import_item = ImportItem.find_by_store_id(se_store.id)
      expect(se_import_item.success_imported).to eq(6)
      expect(se_import_item.import_type).to eq('range_import')
      expect(se_import_item.status).to eq('completed')
    end
  end
end
