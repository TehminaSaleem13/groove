require 'rails_helper'
require 'spec_helper'
describe ScanPackController do
  before(:each) do
    @user = FactoryGirl.create(:user,:name=>'Admin Tester', :username=>"admin", :password=>'12345678')
    sign_in @user
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'test_inventory_warehouse', :is_default=>true, :status=>"active")
    @general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    @store = FactoryGirl.create(:store, :name=>'amazon_store', :inventory_warehouse=>@inv_wh, :store_type=> 'Amazon')
    @scan_pack_settings = ScanPackSetting.new
    @scan_pack_settings.save!
  end
  it "synchronizes available inventory count ,allocated inventory count and sold_qty for non-kit item" do
  	@product = FactoryGirl.create(:product, :total_avail_ext=>50, :store=>@store)
    create_order_info
    @order.set_order_status
    request.accept = "application/json"
    for i in 1..@order_item.qty
      post :scan_barcode, {:input=>@product_barcode.barcode, :state=>"scanpack.rfp.default" , :id=>@order.id}
    end
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh.sold_inventory_warehouses.first.sold_qty).to eq(10)
  end
  it "synchronizes available inventory, allocated inventory and sold_qty for kit items with kit_parsing as single" do
    @product = FactoryGirl.create(:product, :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'single')
    create_order_info
    create_kit_item_info

    request.accept = "application/json"
    @order.set_order_status
    for i in 1..@order_item.qty
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @product_barcode.barcode, :id => @order.id }
    end
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
    expect(@prod_inv_wh.sold_inventory_warehouses.first.sold_qty).to eq(10)
  end
  it "synchronizes available inventory, allocated inventory and sold_qty for kit items with kit_parsing as individual" do
    @product = FactoryGirl.create(:product, :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'individual')
    create_order_info
    create_kit_item_info

    request.accept = "application/json"
    @order.set_order_status
    for i in 1..@order_item.qty
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @kit_product_barcode1.barcode, :id => @order.id }
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @kit_product_barcode2.barcode, :id => @order.id }
    end
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(50)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.available_inv).to eq(40)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(40)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.sold_inventory_warehouses.first.sold_qty).to eq(10)
    expect(@prod_inv_wh2.sold_inventory_warehouses.first.sold_qty).to eq(10)
  end
  it "synchronizes available inventory, allocated inventory and sold_qty for kit items with kit_parsing as depends scan as single" do
    @product = FactoryGirl.create(:product, :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'depends')
    create_order_info
    
    create_kit_item_info

    request.accept = "application/json"
    @order.set_order_status
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)


    for i in 1..@order_item.qty
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @product_barcode.barcode, :id => @order.id }
    end
    
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload
    

    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
    expect(@prod_inv_wh.sold_inventory_warehouses.first.sold_qty).to eq(10)
  end
  it "synchronizes available inventory, allocated inventory and sold_qty for kit items with kit_parsing as depends scan as individual" do
    @product = FactoryGirl.create(:product, :name=>'KIT_PRODUCT', :total_avail_ext=>50, :is_kit=>true, :store=>@store, :kit_parsing=>'depends')
    create_order_info
    
    create_kit_item_info

    request.accept = "application/json"
    @order.set_order_status
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload

    expect(@prod_inv_wh.available_inv).to eq(40)
    expect(@prod_inv_wh.allocated_inv).to eq(10)
    expect(@prod_inv_wh1.available_inv).to eq(50)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(50)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)


    for i in 1..@order_item.qty
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @kit_product_barcode1.barcode, :id => @order.id }
      post :scan_barcode, {:state=>'scanpack.rfp.default', :input => @kit_product_barcode2.barcode, :id => @order.id }
    end
    
    expect(response.status).to eq(200)
    @prod_inv_wh.reload
    @prod_inv_wh1.reload
    @prod_inv_wh2.reload
    

    expect(@prod_inv_wh.available_inv).to eq(50)
    expect(@prod_inv_wh.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.available_inv).to eq(40)
    expect(@prod_inv_wh1.allocated_inv).to eq(0)
    expect(@prod_inv_wh2.available_inv).to eq(40)
    expect(@prod_inv_wh2.allocated_inv).to eq(0)
    expect(@prod_inv_wh1.sold_inventory_warehouses.first.sold_qty).to eq(10)
    expect(@prod_inv_wh2.sold_inventory_warehouses.first.sold_qty).to eq(10)

  end
  def create_order_info
    @product_barcode = FactoryGirl.create(:product_barcode, :product=> @product, :barcode => '12345678')

    @prod_inv_wh = ProductInventoryWarehouses.where(product_id: @product.id).first
    @prod_inv_wh.available_inv = 50
    @prod_inv_wh.allocated_inv = 0
    @prod_inv_wh.product = @product
    @prod_inv_wh.save!

    @order = FactoryGirl.create(:order, :status=>"onhold", :store=>@store)
    @order_item = FactoryGirl.create(:order_item, :order=>@order, :qty=>10, :product_id=>@product.id)

  end
  def create_kit_item_info
    @kit_product1 = FactoryGirl.create(:product, :name=>'kit_product1',:packing_placement=>50)
    @kit_product_barcode1 = FactoryGirl.create(:product_barcode, :product=> @kit_product1, :barcode => 'kit_barcode1')
    @product_kit_sku1 = FactoryGirl.create(:product_kit_sku, :product => @product, :option_product_id=>@kit_product1.id, :qty=>1)
    @prod_inv_wh1 = ProductInventoryWarehouses.where(product_id: @kit_product1.id).first
    @prod_inv_wh1.available_inv = 50
    @prod_inv_wh1.allocated_inv = 0
    @prod_inv_wh1.product = @kit_product1
    @prod_inv_wh1.save!
    @order_item_kit_product1 = FactoryGirl.create(:order_item_kit_product, :order_item => @order_item,
          :product_kit_skus=> @product_kit_sku1)

    @kit_product2 = FactoryGirl.create(:product, :name=>'kit_product2',:packing_placement=>50)
    @kit_product_barcode2 = FactoryGirl.create(:product_barcode, :product=> @kit_product2, :barcode => 'kit_barcode2')
    @product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => @product, :option_product_id=>@kit_product2.id, :qty=>1)
    @prod_inv_wh2 = ProductInventoryWarehouses.where(product_id: @kit_product2.id).first
    @prod_inv_wh2.available_inv = 50
    @prod_inv_wh2.allocated_inv = 0
    @prod_inv_wh2.product = @kit_product2
    @prod_inv_wh2.save!
    @order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => @order_item,
          :product_kit_skus=> @product_kit_sku2)
  end
end