# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
    @user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    sign_in @user
  end
  
  describe "SET product alias" do
    it "sets an alias and copies skus and barcodes also updates order items" do
      request.accept = "application/json"

      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")

      order = FactoryGirl.create(:order, :status=>'awaiting')
      order_item = FactoryGirl.create(:order_item, :product_id=>product_alias.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product_alias.name)

      put :setalias, { :product_orig_id => product_orig.id, product_alias_ids: [product_alias.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(2)
      expect(product_orig.product_barcodes.length).to eq(2)
      expect(Product.all.length).to eq(1)
      order_item.reload
      expect(order_item.product_id).to eq(product_orig.id)
    end
    it "chooses aliases for a product and copies skus and barcodes also updates order items" do
      request.accept = "application/json"

      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product1 = FactoryGirl.create(:product, :name=>"product1")
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1, :sku=>'product_sku1')
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>"BARCODE1")

      product2 = FactoryGirl.create(:product, :name=>"product2")
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'product_sku2')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"BARCODE2")

      order = FactoryGirl.create(:order, :status=>'awaiting')
      order_item = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name)

      put :setalias, { :product_orig_id => product_orig.id, product_alias_ids: [product1.id, product2.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(3)
      expect(product_orig.product_barcodes.length).to eq(3)
      expect(Product.all.length).to eq(1)

      order_item.reload
      expect(order_item.product_id).to eq(product_orig.id)
    end

    it "sets an alias and copies skus and barcodes also updates kit items" do
      request.accept = "application/json"

      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")

      kit_product = FactoryGirl.create(:product, is_kit: 1)
      product_kit_sku = FactoryGirl.create(:product_kit_sku, product_id: kit_product.id, option_product_id: product_alias.id)

      put :setalias, { :product_orig_id => product_orig.id, product_alias_ids: [product_alias.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(2)
      expect(product_orig.product_barcodes.length).to eq(2)
      
      product_kit_sku.reload
      expect(product_kit_sku.option_product_id).to eq(product_orig.id)
    end

    it "chooses aliases for a product and copies skus and barcodes also updates kit items" do
      request.accept = "application/json"

      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product1 = FactoryGirl.create(:product, :name=>"product1")
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1, :sku=>'product_sku1')
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>"BARCODE1")

      product2 = FactoryGirl.create(:product, :name=>"product2")
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'product_sku2')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"BARCODE2")

      kit_product = FactoryGirl.create(:product, is_kit: 1)
      product_kit_sku = FactoryGirl.create(:product_kit_sku, product_id: kit_product.id, option_product_id: product1.id)

      put :setalias, { :product_orig_id => product_orig.id, product_alias_ids: [product1.id, product2.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(3)
      expect(product_orig.product_barcodes.length).to eq(3)

      product_kit_sku.reload
      expect(product_kit_sku.option_product_id).to eq(product_orig.id)
    end
  end

  describe "inventory warehouse count" do
    it "recounts and sets the warehouse available count" do
      request.accept = "application/json"

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      put :adjust_available_inventory, { :id => product.id, :inv_wh_id => inv_wh.id, 
          :inventory_count =>50, :method=>'recount' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(50)
    end

    it "receives and sets the warehouse available count" do
      request.accept = "application/json"

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      put :adjust_available_inventory, { :id => product.id, :inv_wh_id => inv_wh.id, 
          :inventory_count =>50, :method=>'receive' }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(75)
    end

    it "associates the warehouse and the count" do
      request.accept = "application/json"

      inv_wh = FactoryGirl.create(:inventory_warehouse)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)


      put :adjust_available_inventory, { :id => product.id, :inv_wh_id => inv_wh.id, 
          :inventory_count =>50, :method=>'recount' }


      product.reload    
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      expect(product.product_inventory_warehousess.find_by_inventory_warehouse_id(inv_wh.id).available_inv).to eq(50)
    end
  end

  describe "Order status" do
    it "shows order status as onHold when all its items are not allocated" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>true)
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user.role.update_attribute(:add_edit_products, true)
      product1 = FactoryGirl.create(:product)
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1)
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1)

      product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")

      order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name, :inv_status=>'unallocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name, :inv_status=>'unallocated')

      put :updateproductlist, { :id => product1.id, var: "qty", value: "5"  }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      order.reload
      order_item1.reload
      expect(order_item1.product.product_inventory_warehousess.first.available_inv).to eq(4)
      expect(order_item1.inv_status).to eq("allocated")
      expect(order_item2.inv_status).to eq("unallocated")
      expect(order.status).to eq ("onhold")
    end

    it "shows order status as awaiting when all its items are allocated" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>true)
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user.role.update_attribute(:add_edit_products, true)
      product1 = FactoryGirl.create(:product)
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1)
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1)

      product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")

      order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name, :inv_status=>'unallocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name, :inv_status=>'unallocated')

      put :updateproductlist, { :id => product1.id, var: "qty", value: "5"  }
      put :updateproductlist, { :id => product2.id, var: "qty", value: "5"  }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      order.reload
      order_item1.reload
      order_item2.reload
      expect(order_item1.product.product_inventory_warehousess.first.available_inv).to eq(4)
      expect(order_item2.product.product_inventory_warehousess.first.available_inv).to eq(4)
      expect(order_item1.inv_status).to eq("allocated")
      expect(order_item2.inv_status).to eq("allocated")
      expect(order.status).to eq ("awaiting")
    end
    it "auto allocates inventory for awaiting, onhold and serveice issue orders" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>true)
      order1 = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      order2 = FactoryGirl.create(:order, :status=>'onhold', :increment_id=>'1234567891', :store => store)
      order3 = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567892', :store => store)
      product1 = FactoryGirl.create(:product)
      product2 = FactoryGirl.create(:product)
      product3 = FactoryGirl.create(:product)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)
      order_item3 = FactoryGirl.create(:order_item, :product_id=>product3.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>product3.name)
      put :updateproductlist, {:id=>product1.id, :var=> 'qty', :value=>'10'}
      put :updateproductlist, {:id=>product2.id, :var=> 'qty', :value=>'10'}
      put :updateproductlist, {:id=>product3.id, :var=> 'qty', :value=>'10'}
      product1.reload
      product2.reload
      product3.reload
      order_item1.reload
      order_item2.reload
      order_item3.reload
      expect(product1.product_inventory_warehousess.first.allocated_inv).to eq(1)
      expect(product2.product_inventory_warehousess.first.allocated_inv).to eq(1)
      expect(product3.product_inventory_warehousess.first.allocated_inv).to eq(1)
      expect(product1.product_inventory_warehousess.first.available_inv).to eq(9)
      expect(product2.product_inventory_warehousess.first.available_inv).to eq(9)
      expect(product3.product_inventory_warehousess.first.available_inv).to eq(9)
      expect(order_item1.inv_status).to eq('allocated')
      expect(order_item2.inv_status).to eq('allocated')
      expect(order_item3.inv_status).to eq('allocated')
    end

    it "does not auto allocates inventory for scanned and cancelled orders" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>true)
      order1 = FactoryGirl.create(:order, :status=>'scanned', :increment_id=>'1234567890', :store => store)
      order2 = FactoryGirl.create(:order, :status=>'cancelled', :increment_id=>'1234567891', :store => store)
      product1 = FactoryGirl.create(:product)
      product2 = FactoryGirl.create(:product)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)

      put :updateproductlist, {:id=>product1.id, :var=> 'qty', :value=>'10'}
      put :updateproductlist, {:id=>product2.id, :var=> 'qty', :value=>'10'}
      product1.reload
      product2.reload
      expect(product1.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product2.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product1.product_inventory_warehousess.first.available_inv).to eq(10)
      expect(product2.product_inventory_warehousess.first.available_inv).to eq(10)
    end

    it "disables auto-allocation when auto-allocation switch is off" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>false)
      order1 = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      order2 = FactoryGirl.create(:order, :status=>'onhold', :increment_id=>'1234567891', :store => store)
      order3 = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567892', :store => store)
      product1 = FactoryGirl.create(:product)
      product2 = FactoryGirl.create(:product)
      product3 = FactoryGirl.create(:product)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)
      order_item3 = FactoryGirl.create(:order_item, :product_id=>product3.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>product3.name)

      put :updateproductlist, {:id=>product1.id, :var=> 'qty', :value=>'10'}
      put :updateproductlist, {:id=>product2.id, :var=> 'qty', :value=>'10'}
      put :updateproductlist, {:id=>product3.id, :var=> 'qty', :value=>'10'}
      product1.reload
      product2.reload
      product3.reload
      expect(product1.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product2.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product3.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product1.product_inventory_warehousess.first.available_inv).to eq(10)
      expect(product2.product_inventory_warehousess.first.available_inv).to eq(10)
      expect(product3.product_inventory_warehousess.first.available_inv).to eq(10)
    end
  end
  describe "Products CSV" do
    it "generates a csv file in public/csv when product csv is generated for selected products" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      product1 = FactoryGirl.create(:product)
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1)
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1)

      product2 = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'IPHONE5C')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'1234567891')

      post :generate_products_csv, {:select_all=>false, :inverted=>false, :search=>'', :productArray=>[{'id' => product1.id},{'id' => product2.id}]}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)      
      File.exist?(File.dirname(__FILE__) + '/../../public/csv/'+result['filename']).should == true
      File.delete(File.dirname(__FILE__) + '/../../public/csv/'+result['filename'])
    end
  end
end
