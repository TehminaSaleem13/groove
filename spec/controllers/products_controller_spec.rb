# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    user_role = FactoryGirl.create(:role, :name=>'product_spec_tester_role', :make_super_admin => true)
    @user = FactoryGirl.create(:user, :name=>'Product Tester', :username=>"product_spec_tester_role", :role => user_role)
    inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    @store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
  end

  describe 'Permit Shared Imports' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']
    end

    it 'It permit same barcode' do
      @product1 = FactoryGirl.create(:product, store_id: @store.id)
      product_sku = FactoryGirl.create(:product_barcode, barcode: 'PRODUCT_SKU', product_id: @product1.id)
      @product2 = FactoryGirl.create(:product, store_id: @store.id)

      request.accept = 'application/json'

      post :update_product_list, { id: @product2.id, var: 'barcode', value: 'PRODUCT_SKU' }
      res = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(res['status']).to be false
      expect(res['show_alias_popup']).to be true

      post :update_product_list, { id: @product2.id, var: 'barcode', value: 'PRODUCT_SKU', permit_same_barcode: true }
      res = JSON.parse(response.body)
      expect(res['status']).to be true
    end
  end

  describe 'Product Aliasing' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']
    end

    it 'Verify Order Item after product aliasing' do
      product = FactoryGirl.create(:product)
      FactoryGirl.create(:product_sku, product: product, sku: 'PRODUCT1')
      FactoryGirl.create(:product_barcode, product: product, barcode: 'PRODUCT1')

      kit_product = FactoryGirl.create(:product)
      FactoryGirl.create(:product_sku, product: kit_product, sku: 'KITPRODUCT')
      FactoryGirl.create(:product_barcode, product: kit_product, barcode: 'KITPRODUCT')

      kit = FactoryGirl.create(:product, is_kit: 1, kit_parsing: 'individual')
      FactoryGirl.create(:product_sku, product: kit, sku: 'KIT1')
      FactoryGirl.create(:product_barcode, product: kit, barcode: 'KIT1')

      productkitsku = ProductKitSkus.new
      productkitsku.product_id = kit.id
      productkitsku.option_product_id = kit_product.id
      productkitsku.qty = 1
      productkitsku.save

      kit.product_kit_skuss << productkitsku

      order = FactoryGirl.create(:order, status: 'awaiting', store: @store)
      FactoryGirl.create(:order_item, product_id: product.id, qty: 1, price: '10', row_total: '10', order: order, name: product.name)
      request.accept = 'application/json'

      post :set_alias, id: kit.id, product_alias_ids: [product.id]
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
      header = { 'Authorization' => 'Bearer ' + FactoryGirl.create(:access_token, resource_owner_id: @user.id).token }
      request.env['Authorization'] = header['Authorization']

      @product = FactoryGirl.create(:product, is_kit: 0)
      @kit = FactoryGirl.create(:product, is_kit: 1)
      product_sku = FactoryGirl.create(:product_sku, :product=> @product, sku: 'PRODUCT-SKU')
      kit_sku = FactoryGirl.create(:product_sku, :product=> @kit, sku: 'KIT-SKU')
      product_kit_sku = FactoryGirl.create(:product_kit_sku, product: @kit, option_product_id: @product.id)
      (1..201).to_a.each do |index|
        order = FactoryGirl.create(:order, increment_id: "ORDER-#{index}", store: @store)
        order.order_items.create(product: @kit)
      end
    end

    it "should remove products from kit" do
      expect(ProductKitSkus.count).to eq(1)
      post :remove_products_from_kit, { kit_products: [@product.id], id: @kit.id, product: {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(ProductKitSkus.count).to eq(0)
    end
  end
end
