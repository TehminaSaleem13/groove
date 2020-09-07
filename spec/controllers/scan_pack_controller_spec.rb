require 'rails_helper'

RSpec.describe ScanPackController, type: :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    @user = FactoryGirl.create(:user, :username=>'scan_pack_spec_user', :name=>'Scan Pack user', :role => Role.find_by_name('Scan & Pack User'))
    access_restriction = FactoryGirl.create(:access_restriction)
    inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'scan_pack_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>inv_wh, :status => true)
    csv_mapping = FactoryGirl.create(:csv_mapping, :store_id=>@store.id)
    Tenant.create(name: Apartment::Tenant.current, scan_pack_workflow: 'product_first_scan_to_put_wall')

    @products = {}
    skus = %w[ACTION NEW DIGI-RED DIGI-BLU]
    skus.each_with_index do |sku, index|
      @products["product_#{index + 1}"] = FactoryGirl.create(:product)
      FactoryGirl.create(:product_sku, :product=> @products["product_#{index + 1}"], :sku => sku)
      FactoryGirl.create(:product_barcode, :product=> @products["product_#{index + 1}"], barcode: sku)
    end

    ProductBarcode.where(barcode: 'NEW').destroy_all
  end

  describe 'Check Tracking Number Validation' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']
      Tenant.find_by_name(Apartment::Tenant.current).update_attributes(scan_pack_workflow: 'default')
      ScanPackSetting.last.update_attributes(tracking_number_validation_enabled: true, tracking_number_validation_prefixes: 'VERIFY TRACKING, CUSTOM TRACKING', post_scanning_option: 'Record')

      product = FactoryGirl.create(:product)
      FactoryGirl.create(:product_sku, product: product, sku: 'TRACKING')
      FactoryGirl.create(:product_barcode, product: product, barcode: 'TRACKING')

      order = FactoryGirl.create(:order, status: 'awaiting', store: @store)
      FactoryGirl.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order, name: product.name)
    end

    it 'Show Invalid Tracking Number Entered' do
      post :scan_barcode, { input: 'TRACKING', state: 'scanpack.rfp.default', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

      post :scan_barcode, { input: 'TRACKINGNO', state: 'scanpack.rfp.recording', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be false
      expect(result['error_messages']).to include('Doh! The tracking number you have scanned does not appear to be valid. If this scan should be permitted please check your Tracking Number Validation setting in Settings > System > Scan & Pack > Post Scanning Functions')
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')
    end

    it 'Tracking Number Accepted' do
      post :scan_barcode, { input: 'TRACKING', state: 'scanpack.rfp.default', id: Order.last.id, rem_qty: 1 }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['data']['next_state']).to eq('scanpack.rfp.recording')

      post :scan_barcode, { input: 'CUSTOM TRACKINGNO', state: 'scanpack.rfp.recording', id: Order.last.id, rem_qty: 1 }
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
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']

      tote_set = ToteSet.create(name: 'T')

      Range.new(1, (tote_set.max_totes - tote_set.totes.count)).to_a.each do
        tote_set.totes.create(name: "T-#{Tote.all.count + 1}", number: Tote.all.count + 1)
      end
    end

    it 'Single Item Marked Scan' do
      order1 = FactoryGirl.create(:order, :status=>'awaiting', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>@products['product_3'].name)

      order2 = FactoryGirl.create(:order, :status=>'awaiting', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>@products['product_3'].name)

      post :product_first_scan, { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['single_item_order']).to eq(true)
      expect(order1.reload.status).to eq('scanned')
    end

    it 'Assign Item & Set Tote Pending' do
      order3 = FactoryGirl.create(:order, :status=>'awaiting', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>@products['product_3'].name)
      FactoryGirl.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order3, :name=>@products['product_4'].name)

      post :product_first_scan, { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      expect(order3.tote.present? && order3.tote.pending_order).to be true
    end

    it 'Assign Item To Tote' do
      order4 = FactoryGirl.create(:order, :status=>'awaiting', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_3'].name)
      FactoryGirl.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_4'].name)

      post :product_first_scan, { input: 'DIGI-RED' }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      expect(order4.tote.present? && order4.tote.pending_order).to be true

      post :scan_to_tote, { type: 'assigned_to_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      expect(order4.reload.tote.present? && order4.tote.pending_order == false).to be true
    end

    it 'Order Not In Awaiting Status' do
      order5 = FactoryGirl.create(:order, :status=>'onhold', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_1'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order5, :name=>@products['product_1'].name)
      FactoryGirl.create(:order_item, :product_id=>@products['product_2'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order5, :name=>@products['product_2'].name)

      post :product_first_scan, { input: 'ACTION' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be false
      expect(result['no_order']).to eq(true)
      expect(result['notice_messages']).to eq('The remaining orders that contain this item are not ready to be scanned. This is usually because one or more items in the order do not have a barcode assigned yet. You can find all products that require barcodes in the New Products List')
    end

    it 'Scan Complete' do
      order4 = FactoryGirl.create(:order, :status=>'awaiting', store: @store)
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_3'].name)
      FactoryGirl.create(:order_item, :product_id=>@products['product_4'].id, :qty=>2, :price=>"10", :row_total=>"10", :order=>order4, :name=>@products['product_4'].name)

      post :product_first_scan, { input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['assigned_to_tote']).to eq(true)

      post :scan_to_tote, { type: 'assigned_to_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-RED' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      post :product_first_scan, { input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['put_in_tote']).to eq(true)

      post :scan_to_tote, { type: 'put_in_tote', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true

      post :product_first_scan, { input: 'DIGI-BLU' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to be true
      expect(result['scan_tote_to_complete']).to eq(true)

      post :scan_to_tote, { type: 'scan_tote_to_complete', tote: result['tote'], order_item_id: result['order_item']['id'], tote_barcode: 't-1', barcode_input: 'DIGI-BLU' }

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
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']

      ScanPackSetting.last.update_attributes(scan_by_tracking_number: true)
    end

    it 'Cue order by tracking number' do
      order1 = FactoryGirl.create(:order, increment_id:'order1', :status=>'awaiting', store: @store, tracking_num: 'tracking_order_1')
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>@products['product_3'].name)

      order2 = FactoryGirl.create(:order, increment_id:'order2', :status=>'awaiting', store: @store, tracking_num: 'tracking_order_2')
      FactoryGirl.create(:order_item, :product_id=>@products['product_3'].id, :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>@products['product_3'].name)

      get :scan_barcode, { input: 'tracking_order_2', state: 'scanpack.rfo' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['increment_id']).to eq('order2')
    end
  end
end
