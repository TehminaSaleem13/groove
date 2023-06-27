# frozen_string_literal: true

# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, name: 'product_spec_tester_role', make_super_admin: true)
    @user = FactoryBot.create(:user, name: 'Product Tester', username: 'product_spec_tester_role', role: user_role)
    inv_wh = FactoryBot.create(:inventory_warehouse, is_default: true)
    @store = FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id)
    tenant = Apartment::Tenant.current
    Apartment::Tenant.switch!(tenant.to_s)
    @tenant = Tenant.create(name: tenant.to_s, inventory_report_toggle: true)
  end

  after do
    @tenant.destroy
  end

  describe 'Product' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Show Kit Product' do
      product = FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id, name: 'PRODUCT1')
      kit = FactoryBot.create(:product, :with_sku_barcode, is_kit: 1, kit_parsing: 'individual', name: 'KIT1')
      productkitsku = ProductKitSkus.create(product_id: kit.id, option_product_id: product.id, qty: 1)
      kit.product_kit_skuss << productkitsku

      get :show, params: { id: kit.id }
      expect(response.status).to eq(200)
    end

    it 'Get Inventory Settings' do
      product = FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id, name: 'PRODUCT2')
      product_sku = FactoryBot.create(:product_barcode, barcode: 'PRODUCT_SKU2', product_id: product.id)
      request.accept = 'application/json'

      get :get_inventory_setting, params: { id: product.id}
      expect(response.status).to eq(200)
    end

    it 'Update generic' do
      product = FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id, name: 'PRODUCT3')
      product_image = FactoryBot.create(:product_image, image: "MyString", product_id: product.id)
      request.accept = 'application/json'

      post :update_generic, params: { id: product_image.id, flag: 1 }
      expect(response.status).to eq(200)
    end

    it 'Generate Barcode' do
      product = FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id, name: 'PRODUCT3')
      product_sku = FactoryBot.create(:product_barcode, barcode: 'PRODUCT_SKU3', product_id: product.id)
      request.accept = 'application/json'

      get :generate_barcode, params: { id: product.id, productArray: [{ id: product.id }] }
      expect(response.status).to eq(200)
    end
  end

  describe 'Permit Shared Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'permit same barcode' do
      @product1 = FactoryBot.create(:product, store_id: @store.id)
      product_sku = FactoryBot.create(:product_barcode, barcode: 'PRODUCT_SKU', product_id: @product1.id)
      @product2 = FactoryBot.create(:product, store_id: @store.id)

      request.accept = 'application/json'

      post :update_product_list, params: { id: @product2.id, var: 'barcode', value: 'PRODUCT_SKU' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to be false
      expect(res['show_alias_popup']).to be true

      post :update_product_list, params: { id: @product2.id, var: 'barcode', value: 'PRODUCT_SKU', permit_same_barcode: true }
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end
  end

  describe 'Product Aliasing' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Verify Order Item after product aliasing' do
      product = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryBot.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      kit_product = FactoryBot.create(:product)
      FactoryBot.create(:product_sku, product: kit_product, sku: 'KITPRODUCT')
      FactoryBot.create(:product_barcode, product: kit_product, barcode: 'KITPRODUCT')

      kit = FactoryBot.create(:product, is_kit: 1, kit_parsing: 'individual')
      FactoryBot.create(:product_sku, product: kit, sku: 'KIT1')
      FactoryBot.create(:product_barcode, product: kit, barcode: 'KIT1')

      productkitsku = ProductKitSkus.new
      productkitsku.product_id = kit.id
      productkitsku.option_product_id = kit_product.id
      productkitsku.qty = 1
      productkitsku.save

      kit.product_kit_skuss << productkitsku

      order = FactoryBot.create(:order, status: 'awaiting', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order, name: product.name)
      request.accept = 'application/json'

      post :set_alias, params: { id: kit.id, product_alias_ids: [product.id] }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to be true
      expect(Order.multiple_orders_scanning_count([order])[order.id][:unscanned]).to be > 0
    end
  end

  describe 'Product kit modifications' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @product = FactoryBot.create(:product, is_kit: 0)
      @product2 = FactoryBot.create(:product, is_kit: 0)
      @kit = FactoryBot.create(:product, is_kit: 1)
      @kit2 = FactoryBot.create(:product, is_kit: 1)
      product_sku = FactoryBot.create(:product_sku, product: @product, sku: 'PRODUCT-SKU')
      kit_sku = FactoryBot.create(:product_sku, product: @kit, sku: 'KIT-SKU')
      kit2_sku = FactoryBot.create(:product_sku, product: @kit2, sku: 'KIT2-SKU')
      product_kit_sku = FactoryBot.create(:product_kit_sku, product: @kit, option_product_id: @product.id)
      product_kit_sku2 = FactoryBot.create(:product_kit_sku, product: @kit2, option_product_id: @product.id)
      (1..201).to_a.each do |index|
        order = FactoryBot.create(:order, increment_id: "ORDER-#{index}", store: @store)
        order.order_items.create(product: @kit, qty: 1)
        order.order_items.create(product: @kit2, qty: 1)
      end
    end

    it 'removes products from kit' do
      expect(ProductKitSkus.count).to eq(2)
      post :remove_products_from_kit, params: { kit_products: [@product.id], id: @kit.id, product: {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(ProductKitSkus.count).to eq(1)
    end

    it 'add product from kit to kit (product alredy exists)' do
      expect(@kit.product_kit_skuss.first.qty).to eq(1)
      post :add_product_to_kit, params: { product_ids: [@kit2.id], id: @kit.id, product: {} }
      expect(response.status).to eq(200)
      @kit.product_kit_skuss.first.reload
      expect(@kit.product_kit_skuss.first.qty).to eq(2)
    end

    it 'add product from kit to kit' do
      @kit2.product_kit_skuss.first.update(option_product_id: @product2.id)
      @kit2.product_kit_skuss.first.reload
      expect(@kit.product_kit_skuss.count).to eq(1)
      post :add_product_to_kit, params: { product_ids: [@kit2.id], id: @kit.id, product: {} }
      expect(response.status).to eq(200)
      @kit.product_kit_skuss.reload
      expect(@kit.product_kit_skuss.count).to eq(2)
    end
  end

  describe 'Exports & Reports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Generates Product Inventory Report' do
      product = FactoryBot.create(:product, store_id: @store.id)
      FactoryBot.create(:product_sku, sku: 'TESTSKU', product_id: product.id)
      FactoryBot.create(:product_barcode, barcode: 'TESTBARCODE', product_id: product.id)

      ProductInventoryReport.first.update(type: true)
      InventoryReportsSetting.first_or_create(report_email: 'kcpatel006@gmail.com', start_time: 7.day.ago, end_time: Time.current)

      get :generate_product_inventory_report, params: { report_ids: ProductInventoryReport.ids }
      expect(response.status).to eq(200)
    end

    it 'Generates Product Export CSV' do
      FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id)

      get :generate_products_csv, params: { select_all: true }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['filename']).not_to be_nil
    end
  end

  describe 'Product Update' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Update Product' do
      product = FactoryBot.create(:product, store_id: @store.id)
      product_sku = FactoryBot.create(:product_sku, sku: 'TESTSKU', product_id: product.id)
      product_barcode = FactoryBot.create(:product_barcode, barcode: 'TESTBARCODE', product_id: product.id)

      request.accept = 'application/json'

      get :show, params: { id: product.id }
      expect(response.status).to eq(200)
      product_res = JSON.parse(response.body)

      # Update Category and Barcode
      product_res['product']['cats'] = [{ "category": 'TESTCATEGORY' }]
      product_res['product']['post_fn'] = 'category'
      product_res['product']['basicinfo']['multibarcode']['2'] = { "barcode": 'MULTIBARCODE', "packcount": 1 }
      product_res['product']['id'] = product.id
      post :update, params: product_res['product']
      expect(response.status).to eq(200)
      expect(product.product_barcodes.pluck(:barcode)).to include('MULTIBARCODE')
      expect(product.product_cats.pluck(:category)).to include('TESTCATEGORY')

      # Get Product Data
      get :show, params: { id: product.id }
      expect(response.status).to eq(200)
      product_res = JSON.parse(response.body)

      # Update SKU
      product_res['product']['post_fn'] = 'sku'
      product_res['product']['skus'].first['sku'] = 'TESTSKU1'
      product_res['product']['id'] = product.id
      post :update, params: product_res['product']
      expect(response.status).to eq(200)
      expect(product.product_skus.pluck(:sku)).to include('TESTSKU1')

      # Get Product Data
      get :show, params: { id: product.id }
      expect(response.status).to eq(200)
      product_res = JSON.parse(response.body)

      # Skip SKU Check
      product_res['product']['post_fn'] = 'sku'
      product_res['product']['skus'].first['skip_check'] = true
      product_res['product']['id'] = product.id
      post :update, params: product_res['product']
      expect(response.status).to eq(200)
      expect(product.product_skus.pluck(:sku)).to include('TESTSKU1')

      # Update Barcode
      product_res['product']['post_fn'] = 'barcode'
      product_res['product']['barcodes'].first['barcode'] = 'TESTBARCODE1'
      product_res['product']['id'] = product.id
      post :update, params: product_res['product']
      expect(response.status).to eq(200)
      expect(product.product_barcodes.pluck(:barcode)).to include('TESTBARCODE1')

      # Get Product Data
      get :show, params: { id: product.id }
      expect(response.status).to eq(200)
      product_res = JSON.parse(response.body)

      # Skip Barcode Check
      product_res['product']['post_fn'] = 'barcode'
      product_res['product']['barcodes'].first['skip_check'] = true
      product_res['product']['id'] = product.id
      post :update, params: product_res['product']
      expect(response.status).to eq(200)
      expect(product.product_barcodes.pluck(:barcode)).to include('TESTBARCODE1')
    end

    it 'Update Open Order Status' do
      product = FactoryBot.create(:product, store_id: @store.id)
      product_sku = FactoryBot.create(:product_sku, sku: 'PRODUCT_SKU', product_id: product.id)

      order = FactoryBot.create(:order, increment_id: 'ORDER', status: 'onhold', store: @store)
      FactoryBot.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order, name: product.name)

      request.accept = 'application/json'

      expect(order.status).to eq('onhold')

      post :update_product_list, params: { id: product.id, var: 'barcode', value: 'PRODUCT_BARCODE', order_id: order.id }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to be true
      expect(order.reload.status).to eq('awaiting')
    end

    it 'Update Products activity logs' do
      product = FactoryBot.create(:product, store_id: @store.id)
      product_barcode = FactoryBot.create(:product_barcode, barcode: 'TESTBARCODE', product_id: product.id)

      request.accept = 'application/json'

      post :update_product_list, params: { id: product.id, var: 'barcode', value: 'TESTBARCODE' }
      expect(response.status).to eq(200)

      res = JSON.parse(response.body)
      res['var'] = 'barcode'
      res['value'] = 'TESTBARCODE'
      res['id'] = product.id
      expect(response.status).to eq(200)
      expect(product.product_barcodes.pluck(:barcode)).to include('TESTBARCODE')
    end
  end

  describe 'Import Shopify Products' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last)
      shopify_store_credentials = ShopifyCredential.create(shop_name: 'shopify_test', access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopify_store.id, shopify_status: 'open', shipped_status: true, unshipped_status: true, partial_status: true, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false, import_inventory_qoh: true, import_updated_sku: true)
    end

    it 'Refresh the entire catalog' do
      shopify_store = Store.where(store_type: 'Shopify').last
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:products).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_products.yaml'))))

      request.accept = 'application/json'

      expect(Product.count).to eq(0)

      post :import_products, params: { id: shopify_store.id, product_import_range_days: '730', product_import_type: 'refresh_catalog' }
      expect(response.status).to eq(200)

      expect(Product.count).to eq(36)
    end

    it 'Cancel Running Shopify Imports' do
      shopify_store = Store.where(store_type: 'Shopify').last
      StoreProductImport.create(store_id: shopify_store.id)

      expect(StoreProductImport.count).to eq(1)

      request.accept = 'application/json'
      post :cancel_shopify_product_imports
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to be true
      expect(StoreProductImport.count).to eq(0)
    end

    xit 'Product Search' do
      shopify_store = Store.where(store_type: 'Shopify').last
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)
      ProductBarcode.create(product_id: product.id, barcode: '123', order: 0, lot_number: nil, packing_count: '1', is_multipack_barcode: true)

      request.accept = 'application/json'
      post :search, params: { search: 'tRIGGER', sort: '', order: 'DESC', is_kit: '0', limit: '20', offset: '0' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to eq(true)

      request.accept = 'application/json'
      post :search, params: { search: nil, sort: '', order: 'DESC', is_kit: '0', limit: '20', offset: '0' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to eq(false)
      expect(res['message']).to eq('Improper search string')

      request.accept = 'application/json'
      post :search, params: { barcode: '123', sort: '', order: 'DESC', is_kit: '0', limit: '20', offset: '0' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to eq(false)
      expect(res['message']).to eq('Improper search string')
    end

    it 'Print Product Barcode Label' do
      shopify_store = Store.where(store_type: 'Shopify').last
      StoreProductImport.create(store_id: shopify_store.id)
      @user.role.update(add_edit_order_items: true)
      product = Product.create(store_product_id: '0', name: 'TRIGGER SS JERSEY-BLACK-M', product_type: '', store_id: @store.id, status: 'active', packing_instructions: nil, packing_instructions_conf: nil, is_skippable: true, packing_placement: 50, pack_time_adj: nil, kit_parsing: 'individual', is_kit: 0, disable_conf_req: false, total_avail_ext: 0, weight: 0.0, shipping_weight: 0.0, record_serial: false, type_scan_enabled: 'on', click_scan_enabled: 'on', weight_format: 'oz', add_to_any_order: false, base_sku: nil, is_intangible: false, product_receiving_instructions: nil, status_updated: false, is_inventory_product: false, second_record_serial: false, custom_product_1: '', custom_product_2: '', custom_product_3: '', custom_product_display_1: false, custom_product_display_2: false, custom_product_display_3: false, fnsku: nil, asin: nil, fba_upc: '821973374048', isbn: nil, ean: '0821973374048', supplier_sku: nil, avg_cost: 0.0, count_group: nil)

      order = Order.create(increment_id: 'C000209814-B(Duplicate-2)', order_placed_time: Time.current, sku: nil, customer_comments: nil, store_id: @store.id, qty: nil, price: nil, firstname: 'BIKE', lastname: 'ACTIONGmbH', email: 'east@raceface.com', address_1: 'WEISKIRCHER STR. 102', address_2: nil, city: 'RODGAU', state: nil, postcode: '63110', country: 'GERMANY', method: nil, notes_internal: nil, notes_toPacker: nil, notes_fromPacker: nil, tracking_processed: nil, status: 'scanned', scanned_on: Time.current, tracking_num: nil, company: nil, packing_user_id: 2, status_reason: nil, order_number: nil, seller_id: nil, order_status_id: nil, ship_name: nil, shipping_amount: 0.0, order_total: nil, notes_from_buyer: nil, weight_oz: nil, non_hyphen_increment_id: 'C000209814B(Duplicate2)', note_confirmation: false, store_order_id: nil, inaccurate_scan_count: 0, scan_start_time: Time.current, reallocate_inventory: false, last_suggested_at: Time.current, total_scan_time: 1720, total_scan_count: 20, packing_score: 14, custom_field_one: nil, custom_field_two: nil, traced_in_dashboard: false, scanned_by_status_change: false, shipment_id: nil, already_scanned: true, import_s3_key: 'orders/2021-07-29-162759275061.xml', last_modified: nil, prime_order_id: nil, split_from_order_id: nil, source_order_ids: nil, cloned_from_shipment_id: '', ss_label_data: nil, importer_id: nil, clicked_scanned_qty: 17, import_item_id: nil, job_timestamp: nil)
      order_item = OrderItem.create(sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id, name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      # PrintingSetting.create(product_barcode_label_size: '3 x 1')

      request.accept = 'application/json'
      post :print_product_barcode_label, params: { 'sort' => '', 'order' => 'DESC', 'filter' => 'active', 'search' => '', 'select_all' => true, 'inverted' => false, 'is_kit' => 0, 'limit' => 20, 'offset' => 0, 'setting' => '', 'status' => '', 'productArray' => [{ 'id' => order_item.id }], 'product' => { 'status' => '', 'is_kit' => 0 } }
      expect(response.status).to eq(200)

      PrintingSetting.create(product_barcode_label_size: '3 x 1')

      request.accept = 'application/json'
      post :print_product_barcode_label, params: { 'sort' => '', 'order' => 'DESC', 'filter' => 'active', 'search' => '', 'select_all' => true, 'inverted' => false, 'is_kit' => 0, 'limit' => 20, 'offset' => 0, 'setting' => '', 'status' => '', 'productArray' => [{ 'id' => order_item.id }], 'product' => { 'status' => '', 'is_kit' => 0 } }
      expect(response.status).to eq(200)

      PrintingSetting.create(product_barcode_label_size: '2 x 1')

      request.accept = 'application/json'
      post :print_product_barcode_label, params: { 'sort' => '', 'order' => 'DESC', 'filter' => 'active', 'search' => '', 'select_all' => true, 'inverted' => false, 'is_kit' => 0, 'limit' => 20, 'offset' => 0, 'setting' => '', 'status' => '', 'productArray' => [{ 'id' => order_item.id }], 'product' => { 'status' => '', 'is_kit' => 0 } }
      expect(response.status).to eq(200)

      PrintingSetting.create(product_barcode_label_size: '1.5 x 1')

      request.accept = 'application/json'
      post :print_product_barcode_label, params: { 'sort' => '', 'order' => 'DESC', 'filter' => 'active', 'search' => '', 'select_all' => true, 'inverted' => false, 'is_kit' => 0, 'limit' => 20, 'offset' => 0, 'setting' => '', 'status' => '', 'productArray' => [{ 'id' => order_item.id }], 'product' => { 'status' => '', 'is_kit' => 0 } }
      expect(response.status).to eq(200)
    end

    it 'Import Already Running' do
      shopify_store = Store.where(store_type: 'Shopify').last
      StoreProductImport.create(store_id: shopify_store.id)

      request.accept = 'application/json'
      post :import_products, params: { id: shopify_store.id, product_import_range_days: '730', product_import_type: 'refresh_catalog' }
      expect(response.status).to eq(200)
    end

    it 'Import New and Updated Items' do
      shopify_store = Store.where(store_type: 'Shopify').last

      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:products).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_products_updated.yaml'))))

      request.accept = 'application/json'

      product = FactoryBot.create(:product, store_product_id: '32855512345091', name: 'ShopifyProductz')
      FactoryBot.create(:product_sku, product: product, sku: 'SHOPIFYSKU')
      expect(Product.count).to eq(1)
      expect(product.product_skus.count).to eq(1)

      post :import_products, params: { id: shopify_store.id, product_import_type: 'new_updated' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(product.product_skus.count).to eq(2)
    end

    it 'Re Associate Shopify Products'do
      product = FactoryBot.create(:product, name: "Product1", store_product_id: nil)
      shopify_store = Store.where(store_type: 'Shopify').last
      shopify_credential = shopify_store.shopify_credential

      shopify_credential = shopify_credential.update(re_associate_shopify_products:'re_associate_items')
      post :re_associate_all_products_with_shopify, params: { store_id: shopify_store.id}
      expect(response.status).to eq(200)
    end
  end

  describe 'Print' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'Receiving Label' do
      request.accept = 'application/json'

      product = FactoryBot.create(:product, :with_sku_barcode, store_id: @store.id, name: 'PRODUCT1')
      post :print_receiving_label, params: { tenant: Apartment::Tenant.current, productArray: [id: product.id] }
      res = JSON.parse(response.body)
      expect(res['url']).should_not be nil
    end
  end
end
