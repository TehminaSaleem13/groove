# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryBot.create(:role, :name=>'product_spec_tester_role', :make_super_admin => true)
    @user = FactoryBot.create(:user, :name=>'Product Tester', :username=>"product_spec_tester_role", :role => user_role)
    inv_wh = FactoryBot.create(:inventory_warehouse,:is_default => true)
    @store = FactoryBot.create(:store, :inventory_warehouse_id => inv_wh.id)
  end

  describe 'Permit Shared Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'It permit same barcode' do
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

  describe "Product kit modifications" do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      @product = FactoryBot.create(:product, is_kit: 0)
      @kit = FactoryBot.create(:product, is_kit: 1)
      product_sku = FactoryBot.create(:product_sku, :product=> @product, sku: 'PRODUCT-SKU')
      kit_sku = FactoryBot.create(:product_sku, :product=> @kit, sku: 'KIT-SKU')
      product_kit_sku = FactoryBot.create(:product_kit_sku, product: @kit, option_product_id: @product.id)
      (1..201).to_a.each do |index|
        order = FactoryBot.create(:order, increment_id: "ORDER-#{index}", store: @store)
        order.order_items.create(product: @kit, qty: 1)
      end
    end

    it "should remove products from kit" do
      expect(ProductKitSkus.count).to eq(1)
      post :remove_products_from_kit, params: { kit_products: [@product.id], id: @kit.id, product: {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(ProductKitSkus.count).to eq(0)
    end
  end

  describe 'Product Update' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
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
  end

  describe 'Import Shopify Products' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header

      shopify_store = Store.create(name: 'Shopify', status: true, store_type: 'Shopify', inventory_warehouse: InventoryWarehouse.last)
      shopify_store_credentials = ShopifyCredential.create(shop_name: 'shopify_test', access_token: 'shopifytestshopifytestshopifytestshopi', store_id: shopify_store.id, shopify_status: 'open', shipped_status: true, unshipped_status: true, partial_status: true, modified_barcode_handling: 'add_to_existing', generating_barcodes: 'do_not_generate', import_inventory_qoh: false, import_inventory_qoh: true)
    end

    it 'Refresh the entire catalog' do
      shopify_store = Store.where(store_type: 'Shopify').last
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:products).and_return(YAML.load(IO.read(Rails.root.join('spec/fixtures/files/shopify_products.yaml'))))

      request.accept = 'application/json'

      expect(Product.count).to eq(0)

      post :import_products, params: { id: shopify_store.id, product_import_range_days: '730', product_import_type: 'refresh_catalog' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)

      expect(Product.count).to eq(36)
    end
  end
end
