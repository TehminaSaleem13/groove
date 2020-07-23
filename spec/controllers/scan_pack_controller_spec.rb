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
    skus = %w(ACTION NEW DIGI-RED DIGI-BLU)
    skus.each_with_index do |sku, index|
      @products["product_#{index + 1}"] = FactoryGirl.create(:product)
      FactoryGirl.create(:product_sku, :product=> @products["product_#{index + 1}"], :sku => sku)
      FactoryGirl.create(:product_barcode, :product=> @products["product_#{index + 1}"], barcode: sku)
    end

    ProductBarcode.where(barcode: 'NEW').destroy_all
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
end
