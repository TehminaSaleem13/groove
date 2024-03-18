# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanPackController, type: :controller do
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
    Tenant.create(name: Apartment::Tenant.current, scan_pack_workflow: 'product_first_scan_to_put_wall')

    @products = {}
    skus = %w[ACTION NEW DIGI-RED DIGI-BLU]
    skus.each_with_index do |sku, index|
      @products["product_#{index + 1}"] = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: @products["product_#{index + 1}"], sku: sku)
      FactoryBot.create(:product_barcode, product: @products["product_#{index + 1}"], barcode: sku)
    end

    ProductBarcode.where(barcode: 'NEW').destroy_all
  end

  describe 'Check Tracking Number Validation' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
      Tenant.find_by_name(Apartment::Tenant.current).update_attributes(scan_pack_workflow: 'default')
      ScanPackSetting.last.update_attributes(tracking_number_validation_enabled: true, tracking_number_validation_prefixes: 'VERIFY TRACKING, CUSTOM TRACKING', post_scanning_option: 'Record')

      product = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product, sku: 'TRACKING')
      FactoryBot.create(:product_barcode, product: product, barcode: 'TRACKING')

      order = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order, name: product.name)
    end

    it 'Show Invalid Tracking Number Entered' do
      post :scan_barcode, params: { input: 'TRACKING', state: 'scanpack.rfp.default', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

      post :scan_barcode, params: { input: 'TRACKINGNO', state: 'scanpack.rfp.recording', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be false
      expect(result['error_messages']).to include('Doh! The tracking number you have scanned does not appear to be valid. If this scan should be permitted please check your Tracking Number Validation setting in Settings > System > Scan & Pack > Post Scanning Functions')
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')
    end

    it 'Tracking Number Accepted' do
      post :scan_barcode, params: { input: 'TRACKING', state: 'scanpack.rfp.default', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

      post :scan_barcode, params: { input: 'CUSTOM TRACKINGNO', state: 'scanpack.rfp.recording', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['data']['next_state']).to eq('scanpack.rfo')
      expect(result['data']['order_complete']).to eq true
    end
  end

  describe 'Product First Scan to Put Wall' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      tote_set = ToteSet.create(name: 'T')

      Range.new(1, (tote_set.max_totes - tote_set.totes.count)).to_a.each do
        tote_set.totes.create(name: "T-#{Tote.all.count + 1}", number: Tote.all.count + 1)
      end
      ScanPackSetting.last.update(post_scanning_option: 'Barcode')
    end

    it 'Single Item Marked Scan' do
      order1 = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order1, name: @products['product_3'].name)

      order2 = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order2, name: @products['product_3'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['single_item_order']).to eq(true)
      expect(order1.reload.status).to eq('scanned')
    end

    it 'Assign Item & Set Tote Pending' do
      order3 = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order3, name: @products['product_3'].name)
      FactoryBot.create(:order_item, product_id: @products['product_4'].id, qty: 2, price: '10', row_total: '10', order: order3, name: @products['product_4'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      expect(order3.tote.present? && order3.tote.pending_order).to be true
    end

    it 'Assign Item To Tote' do
      order4 = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order4, name: @products['product_3'].name)
      FactoryBot.create(:order_item, product_id: @products['product_4'].id, qty: 2, price: '10', row_total: '10', order: order4, name: @products['product_4'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      expect(order4.tote.present? && order4.tote.pending_order).to be true

      post :scan_to_tote, params: { type: 'assigned_to_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      expect(order4.reload.tote.present? && order4.tote.pending_order == false).to be true
    end

    it 'Order Not In Awaiting Status' do
      order5 = FactoryBot.create(:order, status: 'onhold', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_1'].id, qty: 1, price: '10', row_total: '10', order: order5, name: @products['product_1'].name)
      FactoryBot.create(:order_item, product_id: @products['product_2'].id, qty: 1, price: '10', row_total: '10', order: order5, name: @products['product_2'].name)

      post :product_first_scan, params: { input: 'ACTION' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be false
      expect(result['no_order']).to eq(true)
      expect(result['notice_messages']).to eq('The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List')
    end

    it 'Scan Complete' do
      order4 = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order4, name: @products['product_3'].name)
      FactoryBot.create(:order_item, product_id: @products['product_4'].id, qty: 2, price: '10', row_total: '10', order: order4, name: @products['product_4'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      post :scan_to_tote, params: { type: 'assigned_to_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      post :product_first_scan, params: { input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['put_in_tote']).to eq(true)

      post :scan_to_tote, params: { type: 'put_in_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      post :product_first_scan, params: { input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['scan_tote_to_complete']).to eq(true)

      post :scan_to_tote, params: { type: 'scan_tote_to_complete', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['scan_tote_to_completed']).to eq(true)
    end
  end

  describe 'Get Order For Scan' do
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

      order = FactoryBot.create(:order, increment_id: "#1'0-0", status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 5, price: '10', row_total: '10', order: order, name: product.name)

      order = FactoryBot.create(:order, increment_id: '#1-0"0', status: 'awaiting', store: @store)
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

    describe 'Scan Order Number' do
      before do
        inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
        store = FactoryBot.create(:store, name: 'ss_store', store_type: 'Shipstation API 2', inventory_warehouse: inv_wh, status: true)
        ShipstationRestCredential.create(api_key: '14ccf1296c2043cb9076b90953b7ea9b', api_secret: 'e6fc8ff9f7a7411180d2960eb838e2ca', last_imported_at: '2021-07-12', store_id: store.id, allow_duplicate_order: true)

        order = FactoryBot.create(:order, increment_id: '100', status: 'awaiting', store: store, store_order_id: 1234)
        FactoryBot.create(:order_item, product_id: Product.first.id, qty: 5, price: '10', row_total: '10', order: order, name: Product.first.name)
      end

      it 'returns matched orders as well' do
        get :scan_barcode, params: { input: '100', state: 'scanpack.rfo', store_order_id: 1234 }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['matched_orders']).not_to be_blank
      end
    end

    describe 'Scan Packing Slip' do
      before do
        ScanPackSetting.last.update_attributes(scan_by_packing_slip: true, scan_by_shipping_label: false, scan_by_packing_slip_or_shipping_label: false)
      end

      it 'exact order number match' do
        get :scan_barcode, params: { input: '100', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'no matching order number' do
        get :scan_barcode, params: { input: '500', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with number 500 cannot be found. It may not have been imported yet')
      end

      it 'scan to view match' do
        get :scan_barcode, params: { input: '^#^64', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'hashtag removal' do
        get :scan_barcode, params: { input: '#100', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'hashtag with single quote and hyphen' do
        get :scan_barcode, params: { input: "##1'0-0", state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq("#1'0-0")
      end

      it 'hashtag with double quote and hyphen' do
        get :scan_barcode, params: { input: '#1-0"0', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('#1-0"0')
      end

      it 'hashtag and hyphen removal' do
        get :scan_barcode, params: { input: '#1-00', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'spaces before, after, inside removal' do
        get :scan_barcode, params: { input: ' 1 00 ', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'order number is contained in other number' do
        get :scan_barcode, params: { input: '10', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('10')
      end

      it 'order number is contained and does not exist' do
        get :scan_barcode, params: { input: '1', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with number 1 cannot be found. It may not have been imported yet')
      end
    end

    describe 'Scan Shipping Label' do
      before do
        ScanPackSetting.last.update_attributes(scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false)
      end

      it 'tracking number less than 10 characters' do
        get :scan_barcode, params: { input: '100', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Please provide a valid tracking number with 8 or more characters.')
      end

      it 'exact tracking number match' do
        get :scan_barcode, params: { input: '9400111298370613423837', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('T')
      end

      it 'tracking number with last 5 removed' do
        get :scan_barcode, params: { input: '94001112983706134', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with tracking number 94001112983706134 cannot be found. It may not have been imported yet')
      end

      it 'tracking of 10 or more with prefix' do
        get :scan_barcode, params: { input: 'XX9400111298370613423837', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('T')
      end

      it 'tracking no. after prefix is too short' do
        get :scan_barcode, params: { input: '100000000012345', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with tracking number 100000000012345 cannot be found. It may not have been imported yet')
      end

      it 'tracking no. is close to matching but does not' do
        get :scan_barcode, params: { input: '9600111298370613423837', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with tracking number 9600111298370613423837 cannot be found. It may not have been imported yet')
      end

      it 'tracking number match with suffix added' do
        get :scan_barcode, params: { input: '9400111298370613423837123', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('T')
      end
    end

    describe 'Scan Packing Slip or Shipping Label' do
      before do
        ScanPackSetting.last.update_attributes(scan_by_packing_slip_or_shipping_label: true, scan_by_shipping_label: false, scan_by_packing_slip: false)
      end

      it 'exact match on order number with both enabled' do
        get :scan_barcode, params: { input: 'T', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('T')
      end

      it 'prefix added on order number should not be valid' do
        get :scan_barcode, params: { input: '100T', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include('Order with number 100T cannot be found. It may not have been imported yet')
      end

      it 'order number hashtag removal with both option' do
        get :scan_barcode, params: { input: '#100', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'tracking of 10 or more with prefix' do
        get :scan_barcode, params: { input: '100', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('100')
      end

      it 'Order and tracking number are valid match' do
        get :scan_barcode, params: { input: '1234512345', state: 'scanpack.rfo' }

        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['data']['order']['increment_id']).to eq('TRA')
      end
    end
  end

  describe 'Order Scan' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
      ScanPackSetting.last.update(partial: true, remove_enabled: true)
    end

    it 'Serial Scan with Type Scan (Non-Kit)' do
      product1 = FactoryBot.create(:product, record_serial: true)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')
      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'awaiting', store: @store)
      order_item1 = FactoryBot.create(:order_item, product_id: product1.id, qty: 5, price: 10, row_total: 10, order: order, name: product1.name)

      request.accept = 'application/json'
      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default',on_ex: 'on GPX' }
      expect(response.status).to eq(200)

      # Serial Scan
      post :serial_scan, params: { state: 'scanpack.rfp.recording', barcode: 'PRODUCT1', order_id: order.id, on_ex: 'on GPX', order_item_id: order_item1.id, ask: true, ask_2: false, product_id: product1.id, is_scan: true, serial: 'PRODUCT1SERIAL', scan_pack: { state: 'scanpack.rfp.recording', barcode: 'PRODUCT1', order_id: order.id, order_item_id: order_item1.id, ask: true, ask_2: false, product_id: product1.id, is_scan: true, serial: 'PRODUCT1SERIAL' } }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['next_item']['qty_remaining']).to eq(4)

      # Type Scan
      post :type_scan, params: { id: order.id, count: 2, barcode: 'PRODUCT1', on_ex: 'on GPX', next_item: result['data']['order']['next_item'] }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)

      post :type_scan, params: { id: order.id, on_ex: 'on GPX', count: 2, barcode: 'PRODUCT1', next_item: result['data']['data']['order']['next_item'] }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['data']['next_state']).to eq('scanpack.rfo')
    end

    it 'Serial Scan with Type Scan (Kit)' do
      product = FactoryBot.create(:product, is_kit: 0, record_serial: true)
      kit = FactoryBot.create(:product, is_kit: 1, kit_parsing: 'individual')
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT-SKU')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCT-BARCODE')
      FactoryBot.create(:product_sku, product: kit, sku: 'KIT-SKU')
      FactoryBot.create(:product_barcode, product: kit, barcode: 'KIT-BARCODE')
      FactoryBot.create(:product_kit_sku, product: kit, option_product_id: product.id, qty: 5)
      order = FactoryBot.create(:order, increment_id: 'ORDER-1', store: @store)
      order_item1 = order.order_items.create(product: kit, qty: 1)

      request.accept = 'application/json'
      get :scan_barcode, params: { id: order.id, input: 'PRODUCT-BARCODE', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      # Serial Scan
      post :serial_scan, params: { state: 'scanpack.rfp.recording', barcode: 'PRODUCT-BARCODE', order_id: order.id, order_item_id: order_item1.id, ask: true, ask_2: false, product_id: product.id, is_scan: true, serial: 'PRODUCTSERIAL', scan_pack: { state: 'scanpack.rfp.recording', barcode: 'PRODUCT-BARCODE', order_id: order.id, order_item_id: order_item1.id, ask: true, ask_2: false, product_id: product.id, is_scan: true, serial: 'PRODUCTSERIAL' } }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['next_item']['qty_remaining']).to eq(4)

      # Type Scan
      post :type_scan, params: { id: order.id, count: 2, barcode: 'PRODUCT-BARCODE', next_item: result['data']['order']['next_item'] }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['data']['order']['next_item']['qty_remaining']).to eq(2)
    end

    it 'Scan Order using Partial Barcode' do
      product1 = FactoryBot.create(:product, is_skippable: true)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product1.id, qty: 5, price: '10', row_total: '10', order: order, name: product1.name)
      FactoryBot.create(:order_item, product_id: product2.id, qty: 4, price: '10', row_total: '10', order: order, name: product2.name)

      expect(order.get_items_count).to eq(9)

      get :scan_barcode, params: { input: 'ORDER', state: 'scanpack.rfo' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('ORDER')

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)
      get :scan_barcode, params: { id: order.id, input: 'SKIP', product_id: product1.id, state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      expect(order.reload.get_items_count).to eq(6)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT2', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT2', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'REMOVE-ALL', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(order.reload.get_items_count).to eq(4)
      expect(order.reload.status).to eq('scanned')
      expect(result['data']['next_state']).to eq('scanpack.rfo')
    end

    it 'Scan Order using Remove Barcode' do
      product1 = FactoryBot.create(:product, is_skippable: true)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product1.id, qty: 5, price: '10', row_total: '10', order: order, name: product1.name)
      FactoryBot.create(:order_item, product_id: product2.id, qty: 4, price: '10', row_total: '10', order: order, name: product2.name)

      expect(order.get_items_count).to eq(9)

      get :scan_barcode, params: { input: 'ORDER', state: 'scanpack.rfo' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('ORDER')

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'REMOVE', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      expect(order.reload.get_items_count).to eq(6)
    end

    it 'Retain Skipped Items' do
      ScanPackSetting.last.update_attributes(remove_skipped: false)
      @store.update_attributes(inventory_warehouse_id: InventoryWarehouse.first.id)

      product1 = FactoryBot.create(:product, is_skippable: true, store: @store)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')
      product1_inventory = product1.product_inventory_warehousess.first
      product1_inventory.update_attributes(available_inv: 10)

      product2 = FactoryBot.create(:product, store: @store)
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product1.id, qty: 5, price: '10', row_total: '10', order: order, name: product1.name)
      FactoryBot.create(:order_item, product_id: product2.id, qty: 4, price: '10', row_total: '10', order: order, name: product2.name)

      expect(product1_inventory.reload.available_inv).to eq(5)
      expect(order.get_items_count).to eq(9)

      get :scan_barcode, params: { input: 'ORDER', state: 'scanpack.rfo' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('ORDER')

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'SKIP', product_id: product1.id, state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      expect(product1_inventory.reload.available_inv).to eq(8)
      expect(order.reload.get_items_count).to eq(6)

      skipped_item = order.order_items.where(product_id: product1.id).first

      expect(skipped_item.skipped_qty + skipped_item.qty).to eq(5)
    end

    it 'Scan Order using SCANNED Barcode' do
      ScanPackSetting.last.update(scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')

      product1 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')

      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'awaiting', store: @store, tracking_num: 'ORDER-TRACKING-NUM')
      FactoryBot.create(:order_item, product_id: product1.id, qty: 5, price: '10', row_total: '10', order: order, name: product1.name)

      get :scan_barcode, params: { input: 'ORDER-TRACKING-NUM', state: 'scanpack.rfo' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('ORDER')

      get :scan_barcode, params: { input: 'SCANNED', state: 'scanpack.rfp.default', id: order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')
    end

    it 'Order Clicked Scanned Qty' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      order = FactoryBot.create(:order, increment_id: 'ORDER-1', status: 'awaiting', store: @store, tracking_num: 'ORDER-TRACKING-NUM')
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-WHITE-L', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: true, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product3 = Product.create(store_product_id: '2', name: 'TRIGGER SS JERSEY-WHITE-XL', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product_barcode = ProductBarcode.create(product_id: product1.id, barcode: 'PRODUCT1', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      product_barcode1 = ProductBarcode.create(product_id: product2.id, barcode: 'PRODUCT2', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      product_barcode2 = ProductBarcode.create(product_id: product3.id, barcode: 'PRODUCT3', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      ProductSku.create(sku: 'PRODUCT1', purpose: nil, product_id: product1.id, order: 0)
      ProductSku.create(sku: 'PRODUCT2', purpose: nil, product_id: product2.id, order: 0)
      ProductSku.create(sku: 'PRODUCT3', purpose: nil, product_id: product3.id, order: 0)
      order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      product_kit_sku = ProductKitSkus.create(product_id: product1.id, option_product_id: product2.id, qty: 1, packing_order: 10)
      product_kit_sku1 = ProductKitSkus.create(product_id: product1.id, option_product_id: product3.id, qty: 1, packing_order: 10)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: product_kit_sku.id, scanned_status: "unscanned", scanned_qty: 0)
      OrderItemKitProduct.create(order_item_id: order_item.id, product_kit_skus_id: product_kit_sku1.id, scanned_status: "unscanned", scanned_qty: 0)

      get :click_scan, params: { barcode: product_barcode2.barcode, id: order.id, box_id: nil, on_ex: 'on GPX', scan_pack: { barcode: product_barcode2.barcode, id: order.id, box_id: nil } }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['clicked_scanned_qty']).to eq(1)
    end

    it 'Shared barcode for KIT' do
      product1 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product)
      product2.product_skus.create(sku: 'PRODUCT2')
      product2.product_barcodes.new(barcode: 'PRODUCT1').save(validate: false)

      kit = FactoryBot.create(:product, is_kit: 1, kit_parsing: 'depends')
      kit.product_skus.create(sku: 'KIT-SKU')
      kit.product_barcodes.create(barcode: 'KIT-BARCODE')
      kit.product_kit_skuss.create(option_product_id: product2.id, qty: 5)

      order = FactoryBot.create(:order, increment_id: 'ORDER-1', store: @store)
      order.order_items.create(product_id: kit.id, qty: 1)

      request.accept = 'application/json'
      post :scan_barcode, params: { id: order.id, input: 'PRODUCT1', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['next_item']['qty_remaining']).to eq(4)
    end

    it 'Get Shipment' do
      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'ss_inventory_warehouse')
      store = FactoryBot.create(:store, name: 'sp_store', store_type: 'ShippingEasy', inventory_warehouse: inv_wh, status: true)
      sp_credential = FactoryBot.create(:shipping_easy_credential, store_id: store.id)
      order = FactoryBot.create(:order, increment_id: 'ORDER-TEST', store: store)
      request.accept = 'application/json'

      post :get_shipment, params: { order_id: order.id, store_id: store.id}
      expect(response.status).to eq(200)
    end
  end

  describe 'Expo Logs Process' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token, 'HTTP_ON_GPX' => 'on GPX' }
      @request.headers.merge! header

      ScanPackSetting.last.update(partial: true, remove_enabled: true)
      @order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil, customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'awaiting', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: nil, importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      @product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      @product2 = Product.create(store_product_id: '1', name: 'TRIGGER SS JERSEY-WHITE-L', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      @product3 = Product.create(store_product_id: '3', name: 'TRIGGER SS JERSEY-RED', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 1, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductBarcode.create(product_id: @product1.id, barcode: 'PRODUCT1', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      ProductBarcode.create(product_id: @product2.id, barcode: 'PRODUCT2', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      ProductBarcode.create(product_id: @product3.id, barcode: 'PRODUCT3', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      ProductSku.create(sku: 'PRODUCT1', purpose: nil, product_id: @product1.id, order: 0)
      ProductSku.create(sku: 'PRODUCT2', purpose: nil, product_id: @product2.id, order: 0)
      ProductSku.create(sku: 'PRODUCT3', purpose: nil, product_id: @product3.id, order: 0)

      @order_item =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: @order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: @product1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      @order_item1 =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: @order.id, name: 'TRIGGER SS JERSEY-WHITE-M', product_id: @product2.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      @order_item2 =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: @order.id, name: 'TRIGGER SS JERSEY-RED', product_id: @product3.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 0, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      @product_kit_sku = ProductKitSkus.create(product_id: @product1.id, option_product_id: @product2.id, qty: 1, packing_order: 10)
      @product_kit_sku1 = ProductKitSkus.create(product_id: @product3.id, option_product_id: @product2.id, qty: 1, packing_order: 10)
      OrderItemKitProduct.create(order_item_id: @order_item2.id, product_kit_skus_id: @product_kit_sku1.id, scanned_status: "unscanned", scanned_qty: 0)
    end

    it 'When Scan Order is onhold verify for intangible order item product' do
      order = Order.create(increment_id: '1234', order_placed_time: Time.current, sku: nil, customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'onhold', scanned_on: Time.current, tracking_num: '123344', company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: nil, importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      product1 = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      product2 = Product.create(store_product_id: nil, name: 'Coupon', product_type: nil, store_id: @store.id, status: 'new', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: false, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: true, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductBarcode.create(product_id: product1.id, barcode: 'PRODUCT1', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
      ProductSku.create(sku: 'PRODUCT1', purpose: nil, product_id: product1.id, order: 0)
      ProductSku.create(sku: 'TSKU', purpose: nil, product_id: product2.id, order: 0)
      order_item =  OrderItem.create(sku: 'PRODUCT1', qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item1 =  OrderItem.create(sku: 'TSKU', qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'Coupon', product_id: product2.id, scanned_status: 'unscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 0, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      
      post :scan_pack_v2, params: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
      
      post :scan_pack_v2, params: {data: [{id: nil, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: nil, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
      
      order.update(status: 'awaiting')
      post :scan_pack_v2, params: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')

      order.update(status: 'onhold')
      product2.update(is_intangible: false)
      post :scan_pack_v2, params: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')

      post :scan_pack_v2, params: {data: [{ input: order.tracking_num, state: nil, event: "serial_scan", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(500)

      ScanPackSetting.last.update(post_scanning_option_second: 'PackingSlip')
      order.update(status: 'awaiting')
      post :scan_pack_v2, params: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app", scan_pack: {data: [{id: order.id, input: order.tracking_num, state: nil, event: "verify", updated_at: Time.current, increment_id: order.increment_id, on_ex: 'on GPX'}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end    

    it 'Order Scanned Without Barcode' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.default', Log_count: '1', SKU: 'PRODUCT2', actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: '', name: Apartment::Tenant.current, order_item_id: @order_item.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order item scanned kit item with log press' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      post :scan_pack_v2, params: {data: [{input: "*", id: @order.id, order_item_id: @order_item2.id, time: Time.now, event: "bulk_scan", on_ex: "on GPX", SKU: "PRODUCT3", name: "gpadmin", updated_at: Time.now, increment_id: @order.increment_id, total_qty: 1, product_id: @product2.id}], app: "app", scan_pack: {data: [{input: "*", id: @order.id, order_item_id: @order_item2.id, time: Time.now, event: "bulk_scan", on_ex: "on GPX", SKU: "PRODUCT3", name: "gpadmin", updated_at: Time.now, increment_id: @order.increment_id, total_qty: 1, product_id: @product2.id}], app: "app"}}
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click In Multibox With Single Product' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      post :scan_pack_v2, params:{ data: [{Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }, {Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click In Multibox With Single Product Create Box' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      @box = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box = OrderItemBox.create(order_item_id: @order_item.id, box_id: @box.id, item_qty: 1, kit_id: 1, product_id: @product1.id)

      post :scan_pack_v2, params:{ data: [{Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }, {Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click In Multibox With Single Product Passing Box Id' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      @box = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box = OrderItemBox.create(order_item_id: @order_item.id, box_id: @box.id, item_qty: 1, kit_id: 1, product_id: @product1.id)
      @box1 = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box.update_attributes(order_item_id: @order_item1.id, box_id: @box1.id, kit_id: 3, product_id: 8)

      post :scan_pack_v2, params:{ data: [{box_id: @box.id, Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }, {box_id: @box.id, Log_count: '1', SKU: 'PRODUCT1', qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT1', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT1', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product1.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click In Multibox With Kit' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(scanning_sequence: 'kit_packing_mode', partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      @product1.update_attributes(product_type: 'individual', is_kit: 1)
      post :scan_pack_v2, params:{ data: [{input: 'RESTART', id: @order.id, order_item_id: @order_item.id, time: Time.current, rem_qty: 1, SKU: 'PRODUCT1', Log_count: '', product_name: '', name: Apartment::Tenant.current, state: "scanpack.rfp.default", event: "regular", updated_at: Time.current, increment_id: @order.increment_id}, { Log_count: '1', SKU: 'PRODUCT2', is_kit: true, qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product2.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click In Multibox Passing Without Box Id' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(scanning_sequence: 'kit_packing_mode', partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      @product1.update_attributes(product_type: 'individual', is_kit: 1)
      @box = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box = OrderItemBox.create(order_item_id: @order_item.id, box_id: @box.id, item_qty: 1, kit_id: 1, product_id: @product2.id)

      post :scan_pack_v2, params:{ data: [{Log_count: '1', SKU: 'PRODUCT2', is_kit: true, qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product2.id }, {Log_count: '1', SKU: 'PRODUCT2', is_kit: true, qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product2.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Click Box Already In Multibox Passing Box Id' do
      GeneralSetting.last.update(multi_box_shipments: true)
      ScanPackSetting.last.update(scanning_sequence: 'kit_packing_mode', partial: true, remove_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      @product1.update_attributes(product_type: 'individual', is_kit: 1)
      @box = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box = OrderItemBox.create(order_item_id: @order_item.id, box_id: @box.id, item_qty: 1, kit_id: 1, product_id: @product2.id)
      @box1 = Box.create(name: 'Box 1', order_id: @order.id)
      @order_item_box.update_attributes(order_item_id: @order_item1.id, box_id: @box1.id, kit_id: 3, product_id: 8)

      post :scan_pack_v2, params:{ data: [{box_id: @box.id, Log_count: '1', SKU: 'PRODUCT2', is_kit: true, qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product2.id }, {box_id: @box.id, Log_count: '1', SKU: 'PRODUCT2', is_kit: true, qty_rem: 0, actionBarcode: false, event: 'click_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item1.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current, product_id: @product2.id }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Type scan' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.default', Log_count: '1', SKU: 'PRODUCT2', actionBarcode: false, event: 'type_scan', id: @order.id, increment_id: @order.increment_id, input: 'PRODUCT2', name: Apartment::Tenant.current, order_item_id: @order_item.id, product_name: 'PRODUCT2', rem_qty: 1, time: Time.current, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Bulk Scan' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')

      post :scan_pack_v2, params: { data: [{ state: 'undefined', Log_count: '1', SKU: 'PRODUCT2', event: 'bulk_scan', id: @order.id, increment_id: @order.increment_id, input: '*', name: Apartment::Tenant.current, order_item_id: @order_item.id, product_name: 'PRODUCT2', rem_qty: 1, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Scan All Option' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')

      post :scan_pack_v2, params: { data: [{ state: 'undefined', Log_count: '1', SKU: 'PRODUCT2', event: 'scan_all_items', id: @order.id, increment_id: @order.increment_id, input: '*', name: Apartment::Tenant.current, order_item_id: @order_item.id, product_name: 'PRODUCT2', rem_qty: 1, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Verify' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      GeneralSetting.last.update(email_address_for_packer_notes: 'test@yomail.com')

      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.no_tracking_info', event: 'verify', id: @order.id, increment_id: @order.increment_id, input: @user.confirmation_code, name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)

      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.no_match', event: 'verify', id: @order.id, increment_id: @order.increment_id, input: @user.confirmation_code, name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')

      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.no_match', event: 'verify', id: @order.id, increment_id: @order.increment_id, input: '', name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')

      @order.update(tracking_num: '123456')
      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.no_match', event: 'verify', id: @order.id, increment_id: @order.increment_id, input: '123456', name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')

      ScanPackSetting.last.update(post_scanning_option_second: 'PackingSlip')
      post :scan_pack_v2, params: { data: [{ state: 'scanpack.rfp.no_tracking_info', event: 'verify', id: @order.id, increment_id: @order.increment_id, input: @user.confirmation_code, name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
    end

    it 'Order Scanned Using Serial Scan' do
      ScanPackSetting.last.update(enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      GeneralSetting.last.update(email_address_for_packer_notes: 'test@yomail.com')
      post :scan_pack_v2, params: { data: [{ ask: true, ask_2: false, barcode: 'PRODUCT1', box_id: 'null', clicked: false, event: 'serial_scan', is_scan: true, order_id: @order.id, order_item_id: @order_item.id, product_id: @product1.id, product_lot_id: 'null', second_serial: false, serial: '445', id: @order.id, increment_id: @order.increment_id, input: @user.confirmation_code, state: 'scanpack.rfp.default', name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Order Scanned Using Record' do
      ScanPackSetting.last.update(tracking_number_validation_enabled: true, enable_click_sku: true, scan_by_shipping_label: true, scan_by_packing_slip: false, scan_by_packing_slip_or_shipping_label: false, scanned: true, post_scanning_option: 'Record')
      GeneralSetting.last.update(email_address_for_packer_notes: 'test@yomail.com')

      post :scan_pack_v2, params: { data: [{ ask: true, ask_2: false, barcode: 'PRODUCT1', box_id: 'null', clicked: false, event: 'record', is_scan: true, order_id: @order.id, order_item_id: @order_item.id, product_id: @product1.id, product_lot_id: 'null', second_serial: false, serial: '445', id: @order.id, increment_id: @order.increment_id, input: @user.confirmation_code, state: 'scanpack.rfp.default', name: Apartment::Tenant.current, time: DateTime.now.in_time_zone, updated_at: Time.current }] }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq('OK')
    end

    it 'Verify Order Scanning When Order is Awaiting ' do
      post :verify_order_scanning, params: { id: @order.id}
      expect(response.status).to eq(200)
    end

    it 'Verify Order Scanning When Order is Scanned ' do
      @order.update(status: 'scanned')
      post :verify_order_scanning, params: { id: @order.id}
      expect(response.status).to eq(200)
    end
  end

  describe 'Image Upload' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @order = FactoryBot.create(:order, store_id: @store.id, status: 'scanned', email: 'testemail@yopmail.com')

      Tenant.last.update(packing_cam: true)
      ScanPackSetting.last.update(packing_cam_enabled: true, email_customer_option: true)
    end

    it 'For Packing Cam on S3' do
      post :upload_image_on_s3, params: { base_64_img_upload: true, order_id: @order.id, image: { image: 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII', content_type: 'image/png', original_filename: 'sample_image.png' } }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['status']).to eq(true)
      expect(JSON.parse(response.body)['image']['url']).not_to be_nil
    end
  end

  context 'Post Scanning Options' do
    describe 'Option 1 as Barcode and 2 as Record' do
      let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

      before do
        allow(controller).to receive(:doorkeeper_token) { token1 }
        header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
        @request.headers.merge! header
        Tenant.find_by_name(Apartment::Tenant.current).update_attributes(scan_pack_workflow: 'default')
        ScanPackSetting.last.update_attributes(post_scanning_option: 'Barcode', post_scanning_option_second: 'Record')

        product = FactoryBot.create(:product, :with_sku_barcode)

        @order = FactoryBot.create(:order, status: 'awaiting', store: @store)
        FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: @order, name: product.name, scanned_status: 'scanned')
      end

      it 'Prompts for Recording' do
        post :scan_barcode, params: { input: @order.increment_id, state: 'scanpack.rfo', id: @order.id }
        expect(response.status).to eq(200)
        expect(@order.reload.post_scanning_flag).to eq('Barcode')
      end

      it 'Error message should be visible when shipment handling v2 present ' do
        se_store = Store.create(name: 'ShippingEasy', status: true, store_type: 'ShippingEasy', inventory_warehouse: InventoryWarehouse.last, split_order: 'shipment_handling_v2', troubleshooter_option: true)
        se_store_credentials = ShippingEasyCredential.create(store_id: se_store.id, api_key: 'apikeyapikeyapikeyapikeyapikeyse', api_secret: 'apisecretapisecretapisecretapisecretapisecretapisecretapisecrets', import_ready_for_shipment: false, import_shipped: true, gen_barcode_from_sku: false, popup_shipping_label: false, ready_to_ship: true, import_upc: true, allow_duplicate_id: true)
        ScanPackSetting.last.update(scan_by_shipping_label: true)

        post :scan_barcode, params: { input: 'dsadjsaldj', state: 'scanpack.rfo', id: @order.id, app: 'app'}
        
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include("The tracking number provided was not found. The corresponding order may not have been imported yet.")
      end

      it 'Error message should be visible' do
        ScanPackSetting.last.update(scan_by_shipping_label: true)

        post :scan_barcode, params: { input: 'dsadjsaldj', state: 'scanpack.rfo', id: @order.id, app: 'app'}
        
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include("The tracking number provided was not found. The corresponding order may not have been imported yet.")
      end

      it 'Error message should be visible' do
        ScanPackSetting.last.update(scan_by_packing_slip: true)

        post :scan_barcode, params: { input: 'dsadjsaldj', state: 'scanpack.rfo', id: @order.id, app: 'app'}
        
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['error_messages']).to include("The order number provided was not found. The corresponding order may not have been imported yet.")
      end

      it 'Cue orders for Scan and Pack using Shipping Lables' do
        ScanPackSetting.last.update(scan_by_shipping_label: true)

        post :scan_barcode, params: { input: @order.increment_id, state: 'scanpack.rfo', id: @order.id, app: 'app'}
        expect(response.status).to eq(200)
      end

      it 'correctly sorts the array' do
        order = FactoryBot.create(:order, increment_id: 'ORDER-1', status: 'awaiting', store: @store, tracking_num: 'ORDER-TRACKING-NUM')
        product1 = FactoryBot.create(:product, is_skippable: true, store: @store)
        FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
        FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')
        
        product2 = FactoryBot.create(:product, store: @store)
        
        
        FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
        FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')
        product_barcode = ProductBarcode.create(product_id: product1.id, barcode: 'PRODUCT1', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
        product_barcode1 = ProductBarcode.create(product_id: product2.id, barcode: 'PRODUCT2', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)
        ProductSku.create(sku: 'PRODUCT1', purpose: nil, product_id: product1.id, order: 0)
        ProductSku.create(sku: 'PRODUCT2', purpose: nil, product_id: product2.id, order: 0)
        ProductInventoryWarehouses.where(product_id:  product1.id).first.update(location_primary: '111')
        ProductInventoryWarehouses.where(product_id:  product2.id).first.update(location_primary: '!AAA')
        order_item1 =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
        order_item2 =  OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product2.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
    
        post :scan_barcode, params: { input: order.increment_id, state: 'scanpack.rfo', app: 'app' }
        
        result = JSON.parse response.body
        expect(result["data"]["order"].first["scan_hash"]["data"]["order"]["unscanned_items"].first["location"]).to eq("!AAA")
        expect(result["data"]["order"].first["scan_hash"]["data"]["order"]["unscanned_items"].second["location"]).to eq("111")
      end
    end
  end

  describe 'Order Status' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      product = FactoryBot.create(:product, :with_sku_barcode)

      @order = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: @order, name: product.name, scanned_status: 'scanned')
    end

    it 'Change Order Status To Scanned' do
      post :order_change_into_scanned, params: { id: @order.id}
      expect(response.status).to eq(200)
    end
  end

  describe 'POST #scan_pack_bug_report' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end
    it 'creates a bug report and renders a JSON response' do
      post :scan_pack_bug_report, params: { logs: 'Some logs', other_param: 'Other data' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/json')

    end
  end
end
