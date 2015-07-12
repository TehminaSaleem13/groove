require 'rails_helper'
require 'spec_helper'
describe ScanPackController do
  before(:each) do
    @user = FactoryGirl.create(:user,:name=>'Admin Tester', :username=>"admin", :password=>'12345678')
    sign_in @user
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
    @general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    @store = FactoryGirl.create(:store, :name=>'csv_store', :inventory_warehouse=>@inv_wh, :store_type=> 'CSV')
    @scan_pack_settings = ScanPackSetting.new
    @scan_pack_settings.save!
  end
  it "synchronizes available inventory count ,allocated inventory count and sold_qty" do
  	base_product = FactoryGirl.create(:product, :total_avail_ext=>50, :store=>@store)
    base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)
    base_product_barcode = FactoryGirl.create(:product_barcode, :product=> base_product, :barcode => '12345678')

    order = FactoryGirl.create(:order, :status=>"onhold", :store=>@store)

    prod_inv_wh = ProductInventoryWarehouses.where(product_id: base_product.id).first
    prod_inv_wh.available_inv = 50
    prod_inv_wh.allocated_inv = 0
    prod_inv_wh.product = base_product
    prod_inv_wh.save!

    child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'active')
    child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
    child_product_barcode1 = FactoryGirl.create(:product_barcode, :product=> child_product1, :barcode => '12345678901')
    child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'active')
    child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)
    child_product_barcode2 = FactoryGirl.create(:product_barcode, :product=> child_product2, :barcode => '12345678902')

    order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                  :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'unallocated')
    order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                  :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'unallocated')

    order.set_order_status
    order_item1.reload
    order_item2.reload
    prod_inv_wh.reload
    expect(prod_inv_wh.available_inv).to eq(48)
    expect(prod_inv_wh.allocated_inv).to eq(2)
    expect(order_item1.inv_status).to eq('allocated')
    expect(order_item2.inv_status).to eq('allocated')
    # order.set_order_status
    request.accept = "application/json"
    post :scan_barcode, {:input=>child_product_barcode1.barcode, :state=>"scanpack.rfp.default" , :id=>order.id}
    expect(response.status).to eq(200)

    post :scan_barcode, {:input=>child_product_barcode2.barcode, :state=>"scanpack.rfp.default" , :id=>order.id}
    expect(response.status).to eq(200)

    order.reload
    prod_inv_wh.reload
    expect(order.status).to eq('scanned')
    expect(prod_inv_wh.available_inv).to eq(48)
    expect(prod_inv_wh.allocated_inv).to eq(0)
    sold_qty = 0
    for i in 1..prod_inv_wh.sold_inventory_warehouses.length
      sold_qty += prod_inv_wh.sold_inventory_warehouses[i-1].sold_qty
    end
    expect(sold_qty).to eq(2)
  end
end
