# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
    @user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    sign_in @user

    Delayed::Worker.delay_jobs = false
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
		# We do not put orders on hold due to inventory
    # it "shows order status as onHold when all its items are not allocated" do
    #   request.accept = "application/json"
    #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true, :inventory_auto_allocation=>true)
    #   inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    #   store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
    #   @user.role.update_attribute(:add_edit_products, true)
    #   product1 = FactoryGirl.create(:product)
    #   product1_sku = FactoryGirl.create(:product_sku, :product=> product1)
    #   product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1)
		#
    #   product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
    #   product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
    #   product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")
		#
    #   order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
    #   order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name, :inv_status=>'unallocated')
    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name, :inv_status=>'unallocated')
		#
    #   put :update_product_list, { :id => product1.id, var: "qty", value: "5"  }
		#
    #   expect(response.status).to eq(200)
    #   result = JSON.parse(response.body)
    #   order.reload
    #   order_item1.reload
    #   expect(order_item1.product.product_inventory_warehousess.first.available_inv).to eq(4)
    #   expect(order_item1.inv_status).to eq("allocated")
    #   expect(order_item2.inv_status).to eq("unallocated")
    #   expect(order.status).to eq ("onhold")
    # end

    # it "shows order status as awaiting when all its items are allocated" do
    #   request.accept = "application/json"
    #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    #   inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    #   store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
    #   @user.role.update_attribute(:add_edit_products, true)
    #   product1 = FactoryGirl.create(:product)
    #   product1_sku = FactoryGirl.create(:product_sku, :product=> product1)
    #   product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1)
		#
    #   product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
    #   product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
    #   product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"2456789")
		#
    #   order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
    #   order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name)
    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name)
		#
    #   put :update_product_list, { :id => product1.id, var: "qty", value: "5"  }
    #   put :update_product_list, { :id => product2.id, var: "qty", value: "5"  }
		#
    #   expect(response.status).to eq(200)
    #   result = JSON.parse(response.body)
    #   order.reload
    #   order_item1.reload
    #   order_item2.reload
    #   expect(order_item1.product.product_inventory_warehousess.first.available_inv).to eq(4)
    #   expect(order_item2.product.product_inventory_warehousess.first.available_inv).to eq(4)
    #   expect(order_item1.inv_status).to eq("allocated")
    #   expect(order_item2.inv_status).to eq("allocated")
    #   expect(order.status).to eq ("awaiting")
    # end
    it "auto allocates inventory for awaiting, onhold and serveice issue orders" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
      order1 = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      order2 = FactoryGirl.create(:order, :status=>'onhold', :increment_id=>'1234567891', :store => store)
      order3 = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567892', :store => store)
      product1 = FactoryGirl.create(:product, :name=>"Apple iPhone 5S")
      product2 = FactoryGirl.create(:product, :name=>"Apple iPhone 5T")
      product3 = FactoryGirl.create(:product, :name=>"Apple iPhone 5Z")

      product_sku1 = FactoryGirl.create(:product_sku, :product=> product1, :sku=>"E-VEGAN-EPIC1")
      product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"E-VEGAN-EPIC2")
      product_sku3 = FactoryGirl.create(:product_sku, :product=> product3, :sku=>"E-VEGAN-EPIC3")

      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)
      order_item3 = FactoryGirl.create(:order_item, :product_id=>product3.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>product3.name)
      put :update_product_list, {:id=>product1.id, :var=> 'qty_on_hand', :value=>'10'}
      expect(response.status).to eq(200)
      put :update_product_list, {:id=>product2.id, :var=> 'qty_on_hand', :value=>'10'}
      expect(response.status).to eq(200)
      put :update_product_list, {:id=>product3.id, :var=> 'qty_on_hand', :value=>'10'}
      expect(response.status).to eq(200)
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
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
      order1 = FactoryGirl.create(:order, :status=>'scanned', :increment_id=>'1234567890', :store => store)
      order2 = FactoryGirl.create(:order, :status=>'cancelled', :increment_id=>'1234567891', :store => store)
      product1 = FactoryGirl.create(:product)
      product2 = FactoryGirl.create(:product)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)

      put :update_product_list, {:id=>product1.id, :var=> 'qty_on_hand', :value=>'10'}
      put :update_product_list, {:id=>product2.id, :var=> 'qty_on_hand', :value=>'10'}
      product1.reload
      product2.reload
      expect(product1.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product2.product_inventory_warehousess.first.allocated_inv).to eq(0)
      expect(product1.product_inventory_warehousess.first.available_inv).to eq(10)
      expect(product2.product_inventory_warehousess.first.available_inv).to eq(10)
    end

    # it "disables auto-allocation when inventory tracking switch is off" do
    #   request.accept = "application/json"
    #   inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    #   store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
    #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>false, :hold_orders_due_to_inventory=>true)
    #   order1 = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
    #   order2 = FactoryGirl.create(:order, :status=>'onhold', :increment_id=>'1234567891', :store => store)
    #   order3 = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567892', :store => store)
    #   product1 = FactoryGirl.create(:product)
    #   product2 = FactoryGirl.create(:product)
    #   product3 = FactoryGirl.create(:product)
		#
    #   order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order1, :name=>product1.name)
    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order2, :name=>product2.name)
    #   order_item3 = FactoryGirl.create(:order_item, :product_id=>product3.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order3, :name=>product3.name)
		#
    #   put :update_product_list, {:id=>product1.id, :var=> 'qty', :value=>'10'}
    #   put :update_product_list, {:id=>product2.id, :var=> 'qty', :value=>'10'}
    #   put :update_product_list, {:id=>product3.id, :var=> 'qty', :value=>'10'}
    #   product1.reload
    #   product2.reload
    #   product3.reload
    #   expect(product1.product_inventory_warehousess.first.allocated_inv).to eq(0)
    #   expect(product2.product_inventory_warehousess.first.allocated_inv).to eq(0)
    #   expect(product3.product_inventory_warehousess.first.allocated_inv).to eq(0)
    #   expect(product1.product_inventory_warehousess.first.available_inv).to eq(10)
    #   expect(product2.product_inventory_warehousess.first.available_inv).to eq(10)
    #   expect(product3.product_inventory_warehousess.first.available_inv).to eq(10)
    # end
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


  it "Should create a new product" do
    request.accept = "application/json"
    access_restriction = FactoryGirl.create(:access_restriction)
    inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true, :name=>'default_inventory_warehouse')
    store = FactoryGirl.create(:store, :name=>'Default Store', :store_type=>'system', :inventory_warehouse=>inv_wh, :status => true)
    general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    post :create
    expect(response.status).to eq(200)
    expect(Product.all.count).to eq(1)
  end

  it "Should update existing product" do
    request.accept = "application/json"
    access_restriction = FactoryGirl.create(:access_restriction)
    inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true, :name=>'default_inventory_warehouse')
    store = FactoryGirl.create(:store, :name=>'Default Store', :store_type=>'system', :inventory_warehouse=>inv_wh, :status => true)
    general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
    post :create
    expect(response.status).to eq(200)
    expect(Product.all.count).to eq(1)
    product = Product.all.first
    #Product params need to be passes everytime otherwise blank info will be saved for product like name, store_product_id etc.
    product_params = {id: product.id, store_product_id: 0, name: "Dread Wax", store_id: store.id, status: "active", is_skippable: false, is_kit: 0}
    put :update, {id: product.id, basicinfo: product_params}
    product.reload
    expect(response.status).to eq(200)
    expect(product.status).to eq("new")
    expect(product.name).to eq("Dread Wax")
    expect(product.is_skippable).to eq(false)
    expect(product.is_kit).to eq(0)
    expect(product.product_skus.count).to eq(0)
    expect(product.product_barcodes.count).to eq(0)
    expect(product.product_cats.count).to eq(0)

    put :update, {id: product.id, basicinfo: product_params, post_fn: 'sku', skus: [{product_id: product.id, purpose: nil, sku: "P-WAX"}]}
    product.reload
    expect(response.status).to eq(200)
    expect(product.status).to eq("new")
    expect(product.product_skus.count).to eq(1)
    expect(product.product_barcodes.count).to eq(0)
    expect(product.product_cats.count).to eq(0)

    put :update, {id: product.id, basicinfo: product_params, post_fn: 'barcode', barcodes: [{product_id: product.id, barcode: "P-WAX"}]}
    product.reload
    expect(response.status).to eq(200)
    expect(product.status).to eq("active")
    expect(product.product_skus.count).to eq(1)
    expect(product.product_barcodes.count).to eq(1)
    expect(product.product_cats.count).to eq(0)
    expect(product.status).to eq("active")

    put :update, {id: product.id, basicinfo: product_params, post_fn: 'category', cats: [{product_id: product.id, category: "TEST"}]}
    product.reload
    expect(response.status).to eq(200)
    expect(product.status).to eq("active")
    expect(product.product_skus.count).to eq(1)
    expect(product.product_barcodes.count).to eq(1)
    expect(product.product_cats.count).to eq(1)
    expect(product.status).to eq("active")
  end

  # describe "Import Products" do
  #   it "It should import products from magento store" do
  #   request.accept = "application/json"
  #   access_restriction = FactoryGirl.create(:access_restriction)
  #   inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true, :name=>'default_inventory_warehouse')
  #   store = FactoryGirl.create(:store, :name=>'Magento Store', :store_type=>'Magento', :inventory_warehouse=>inv_wh, :status => true)
  #   credentials = FactoryGirl.create(:magento_credential, :host=>"http://www.groovepacker.com/store", :username => "gpacker", :api_key => "gpacker.jonnyclean@xoxy.net", :store_id => store.id, import_products: true, last_imported_at: Time.now-10.days)
  #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
  #   get :import_products,{:id => store.id}
  #   expect(response.status).to eq(200)
  #   end
  # end
end
