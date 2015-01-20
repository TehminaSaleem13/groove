require 'rails_helper'
require 'spec_helper'
describe OrdersController do
  it "synchronizes available inventory count and allocated inventory count" do
  	@inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
  	@general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
  	@store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :barcode=> '12345678', :store=>@store)
  	@prod_inv_wh = @inv_wh.product_inventory_warehousess.first
  	@prod_inv_wh.available_inv = 50
  	@prod_inv_wh.allocated_inv = 50
  	@prod_inv_wh.inventory_warehouse = @store.inventory_warehouse
  	@prod_inv_wh.product = @product
  	@prod_inv_wh.save!
    @order = FactoryGirl.create(:order, :status=>"onhold", :store=>@store)
    @order_item = FactoryGirl.create(:order_item, :order=>@order, :qty=>10)
    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(60)
  end
  it "inventory count remains unchanged if inventory_tracking is false " do
  	@inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
  	@general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>false, :hold_orders_due_to_inventory=>false)
  	@store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :barcode=> '12345678', :store=>@store)
  	@prod_inv_wh = @inv_wh.product_inventory_warehousess.first
  	@prod_inv_wh.available_inv = 50
  	@prod_inv_wh.allocated_inv = 50
  	@prod_inv_wh.inventory_warehouse = @store.inventory_warehouse
  	@prod_inv_wh.product = @product
  	@prod_inv_wh.save!
    @order = FactoryGirl.create(:order, :status=>"onhold", :store=>@store)
    @order_item = FactoryGirl.create(:order_item, :order=>@order, :qty=>10)
    request.accept = "application/json"
    @order.update_order_status
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    puts @prod_inv_wh.inspect
    expect(@prod_inv_wh.available_inv).to eq(50)
    expect(@prod_inv_wh.allocated_inv).to eq(50)
  end
end