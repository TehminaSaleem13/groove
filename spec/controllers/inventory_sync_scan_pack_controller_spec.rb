require 'rails_helper'
require 'spec_helper'
describe ScanPackController do
  it "synchronizes allocated inventory count and sold inventory count" do
  	@user = FactoryGirl.create(:user,:name=>'Admin Tester', :username=>"admin", :password=>'12345678')
    sign_in @user
  	@inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
  	@general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
  	@store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :barcode=> '12345678', :store=>@store)
    @product_barcode = FactoryGirl.create(:product_barcode, :barcode=>@product.barcode, :product=>@product)
  	@prod_inv_wh = @product.product_inventory_warehousess.first
  	@prod_inv_wh.available_inv = 50
  	@prod_inv_wh.allocated_inv = 50
  	@prod_inv_wh.inventory_warehouse = @store.inventory_warehouse
  	@prod_inv_wh.product = @product
  	@prod_inv_wh.save!
  	@order = FactoryGirl.create(:order, :status=>"awaiting", :store=>@store)
    @order_item = FactoryGirl.create(:order_item, :order=>@order, :qty=>10)
    @scan_pack_settings = ScanPackSetting.new
    @scan_pack_settings.save!
    request.accept = "application/json"
    for i in 1..@order_item.qty
    post :scan_barcode, {:input=>@product.barcode, :state=>"scanpack.rfp.default" , :id=>@order.id}
    end
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(50)
    expect(@prod_inv_wh.sold_inventory_warehouses.first.sold_qty).to eq(10)
  end
end