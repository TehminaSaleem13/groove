require 'rails_helper'
require 'spec_helper'
describe OrdersController do
	before(:each) do
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
    @general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    @store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
  end
  it "synchronizes available inventory count and allocated inventory count" do
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :barcode=> '12345678', :store=>@store)

    create_order_info
    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
  end
  it "inventory count remains unchanged if inventory_tracking is false " do
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :barcode=> '12345678', :store=>@store)

    create_order_info
    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
  end
  it "synchronizes available inventory and allocated inventory for kit items for kit_parsing as single" do
  	@product = FactoryGirl.create(:product, :barcode=>'12345678', :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'single')

    create_order_info
    create_kit_item_info

    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
  end
  it "synchronizes available inventory and allocated inventory for kit items for kit_parsing as individual" do
  	@product = FactoryGirl.create(:product, :barcode=>'12345678', :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'individual')

    create_order_info
    create_kit_item_info

    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(50)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.available_inv).to eq(40)
    expect(@prod_inv_wh1.allocated_inv).to eq(10)
    expect(@prod_inv_wh2.available_inv).to eq(40)
    expect(@prod_inv_wh2.allocated_inv).to eq(10)
  end
  it "synchronizes available inventory and allocated inventory for kit items for kit_parsing as depends" do
  	@product = FactoryGirl.create(:product, :barcode=>'12345678', :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'depends')

	  create_order_info
    create_kit_item_info

    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
  end
  def create_order_info
    @prod_inv_wh = ProductInventoryWarehouses.where(product_id: @product.id).first
    @prod_inv_wh.available_inv = 50
    @prod_inv_wh.allocated_inv = 0
    @prod_inv_wh.product = @product
    @prod_inv_wh.save!

    @order = FactoryGirl.create(:order, :status=>"onhold", :store=>@store)
    @order_item = FactoryGirl.create(:order_item, :order=>@order, :qty=>10, :product_id=>@product.id)
  end
  def create_kit_item_info
    @kit_product1 = FactoryGirl.create(:product, :barcode=>'kit_barcode1', :name=>'kit_product1',:packing_placement=>50)
    @product_kit_sku1 = FactoryGirl.create(:product_kit_sku, :product => @product, :option_product_id=>@kit_product1.id)
    @prod_inv_wh1 = ProductInventoryWarehouses.where(product_id: @kit_product1.id).first
    @prod_inv_wh1.available_inv = 50
    @prod_inv_wh1.allocated_inv = 0
    @prod_inv_wh1.product = @kit_product1
    @prod_inv_wh1.save!

    @kit_product2 = FactoryGirl.create(:product, :name=>'kit_product2',:packing_placement=>50)
    @product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => @product, :option_product_id=>@kit_product2.id)
    @prod_inv_wh2 = ProductInventoryWarehouses.where(product_id: @kit_product2.id).first
    @prod_inv_wh2.available_inv = 50
    @prod_inv_wh2.allocated_inv = 0
    @prod_inv_wh2.product = @kit_product2
    @prod_inv_wh2.save!
  end
end