require 'rails_helper'

RSpec.describe ScanPackController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user = FactoryBot.create(:user, :username=>'scan_pack_spec_user', :name=>'Scan Pack user', :role => Role.find_by_name('Scan & Pack User'))
    access_restriction = FactoryBot.create(:access_restriction)
    inv_wh = FactoryBot.create(:inventory_warehouse, :name=>'scan_pack_inventory_warehouse')
    @store = FactoryBot.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>inv_wh, :status => true)
    csv_mapping = FactoryBot.create(:csv_mapping, :store_id=>@store.id)
    Tenant.create(name: Apartment::Tenant.current, scan_pack_workflow: 'product_first_scan_to_put_wall')

    @products = {}
    skus = %w[ACTION NEW DIGI-RED DIGI-BLU]
    skus.each_with_index do |sku, index|
      @products["product_#{index + 1}"] = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, :product=> @products["product_#{index + 1}"], :sku => sku)
      FactoryBot.create(:product_barcode, :product=> @products["product_#{index + 1}"], barcode: sku)
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
      order1 = FactoryBot.create(:order, :status=>'awaiting', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>@products['product_3'].name)

      order2 = FactoryBot.create(:order, :status=>'awaiting', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>@products['product_3'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['single_item_order']).to eq(true)
      expect(order1.reload.status).to eq('scanned')
    end

    it 'Assign Item & Set Tote Pending' do
      order3 = FactoryBot.create(:order, :status=>'awaiting', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>@products['product_3'].name)
      FactoryBot.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order3, :name=>@products['product_4'].name)

      post :product_first_scan, params: { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      expect(order3.tote.present? && order3.tote.pending_order).to be true
    end

    it 'Assign Item To Tote' do
      order4 = FactoryBot.create(:order, :status=>'awaiting', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_3'].name)
      FactoryBot.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_4'].name)

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
      order5 = FactoryBot.create(:order, :status=>'onhold', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_1'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order5, :name=>@products['product_1'].name)
      FactoryBot.create(:order_item, :product_id=>@products['product_2'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order5, :name=>@products['product_2'].name)

      post :product_first_scan, params: { input: 'ACTION' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be false
      expect(result['no_order']).to eq(true)
      expect(result['notice_messages']).to eq('The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List')
    end

    it 'Scan Complete' do
      order4 = FactoryBot.create(:order, :status=>'awaiting', store: @store)
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_3'].name)
      FactoryBot.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_4'].name)

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
    end

    it 'Cue order by tracking number' do
      ScanPackSetting.last.update(scan_by_shipping_label: true, scan_by_packing_slip: false)

      order1 = FactoryBot.create(:order, increment_id:'order1', :status=>'awaiting', store: @store, tracking_num: 'tracking_order_1')
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>@products['product_3'].name)

      order2 = FactoryBot.create(:order, increment_id:'order2', :status=>'awaiting', store: @store, tracking_num: 'tracking_order_2')
      FactoryBot.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>@products['product_3'].name)

      get :scan_barcode, params: { input: 'tracking_order_2', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('order2')
    end

    it 'Cue order by Scan to view_order' do
      order = FactoryBot.create(:order, increment_id: 'order', status: 'awaiting', store: @store, store_order_id: 439041093)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order, name: @products['product_3'].name)

      get :scan_barcode, params: { input: '^#^1A2B3C45^', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('order')
    end

    it 'Cue order by order number' do
      order = FactoryBot.create(:order, increment_id: 'order', status: 'awaiting', store: @store, store_order_id: 439041093)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order, name: @products['product_3'].name)

      get :scan_barcode, params: { input: 'order', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('order')
    end

    it 'No order by tracking number' do
      ScanPackSetting.last.update_attributes(scan_by_shipping_label: true, scan_by_packing_slip: false)

      order = FactoryBot.create(:order, increment_id: 'order', status: 'awaiting', store: @store, store_order_id: 439041093)
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order, name: @products['product_3'].name)

      get :scan_barcode, params: { input: 'order', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to eq(["Order with tracking number order cannot be found. It may not have been imported yet"])
    end

    it 'No order by order number' do
      ScanPackSetting.last.update_attributes(scan_by_packing_slip: true, scan_by_shipping_label: false)

      get :scan_barcode, params: { input: 'order', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['error_messages']).to eq(["Order with number order cannot be found. It may not have been imported yet"])
    end

    it 'Cue order by tracking number or order number' do
      ScanPackSetting.last.update_attributes(scan_by_packing_slip_or_shipping_label: true, scan_by_shipping_label: false, scan_by_packing_slip: false)

      order = FactoryBot.create(:order, increment_id: 'order', status: 'awaiting', store: @store, tracking_num: '439041093')
      FactoryBot.create(:order_item, product_id: @products['product_3'].id, qty: 1, price: '10', row_total: '10', order: order, name: @products['product_3'].name)

      get :scan_barcode, params: { input: 'order', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('order')
    end
  end

  describe 'Order Scan' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
      ScanPackSetting.last.update_attributes(partial: true)
    end

    it 'Scan Order using Partial Barcode' do
      product1 = FactoryBot.create(:product, is_skippable: true)
      FactoryBot.create(:product_sku, product: product1, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product1, barcode: 'PRODUCT1')

      product2 = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product2, sku: 'PRODUCT2')
      FactoryBot.create(:product_barcode, product: product2, barcode: 'PRODUCT2')

      order = FactoryBot.create(:order, increment_id:'ORDER', :status=>'awaiting', store: @store)
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

      get :scan_barcode, params: { id: order.id, input: 'SKIP', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      expect(order.reload.get_items_count).to eq(7)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT2', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PRODUCT2', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)

      get :scan_barcode, params: { id: order.id, input: 'PARTIAL', state: 'scanpack.rfp.default' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(order.reload.get_items_count).to eq(5)
      expect(order.reload.status).to eq('scanned')
      expect(result['data']['next_state']).to eq('scanpack.rfo')
    end
  end
end
