# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    user_role = FactoryGirl.create(:role, :name=>'product_spec_tester_role', :make_super_admin => true)
    @user = FactoryGirl.create(:user, :name=>'Product Tester', :username=>"product_spec_tester_role", :role => user_role)
    inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    @store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
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