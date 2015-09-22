# require 'spec_helper'
require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
    @user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    sign_in @user
  end
  
  describe "Generate Barcode From SKU" do
    it "child products remain in 'new' state after barcode generation if base product is in 'new' state" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :hold_orders_due_to_inventory=>false)
      order = FactoryGirl.create(:order, :status=>'onhold')
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'new')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name)
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product1.id}]}
      expect(response.status).to eq(200)
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product2.id}]}
      expect(response.status).to eq(200)
      
      base_product.reload
      child_product1.reload
      child_product2.reload
      expect(base_product.status).to eq('new')
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
    end

    it "child products will remain in 'new' state, if barcodes are not generated, though base product is in 'active' state" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :hold_orders_due_to_inventory=>false)
      order = FactoryGirl.create(:order, :status=>'onhold')
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'new')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name)
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>base_product.id}]}
      expect(response.status).to eq(200)
      
      base_product.reload
      child_product1.reload
      child_product2.reload
      expect(base_product.status).to eq('active')
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
    end
    it "child products move to 'active' state after barcode generation, only if the base product is in 'active' state" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :hold_orders_due_to_inventory=>false)
      order = FactoryGirl.create(:order, :status=>'onhold')
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)
      base_product_barcode = FactoryGirl.create(:product_barcode, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name)
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product1.id}]}
      expect(response.status).to eq(200)
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product2.id}]}
      expect(response.status).to eq(200)
      
      base_product.reload
      child_product1.reload
      child_product2.reload
      expect(base_product.status).to eq('active')
      expect(child_product1.status).to eq('active')
      expect(child_product2.status).to eq('active')
    end
    it "moves the order to awaiting state if the child items and the base product are all in 'active' state" do
      request.accept = "application/json"
      general_setting = FactoryGirl.create(:general_setting, :hold_orders_due_to_inventory=>false)
      order = FactoryGirl.create(:order, :status=>'onhold')
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'new')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)
      base_product_barcode = FactoryGirl.create(:product_barcode, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name)
      expect(child_product1.status).to eq('new')
      expect(child_product2.status).to eq('new')
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>base_product.id}]}
      expect(response.status).to eq(200)
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product1.id}]}
      expect(response.status).to eq(200)
      put :generate_barcode, {:select_all=>false, :inverted=>false, :productArray=>[{:id=>child_product2.id}]}
      expect(response.status).to eq(200)
      
      base_product.reload
      child_product1.reload
      child_product2.reload
      order.reload
      expect(base_product.status).to eq('active')
      expect(child_product1.status).to eq('active')
      expect(child_product2.status).to eq('active')
      expect(order.status).to eq('awaiting')
    end
  end
  describe "Inventory Tracking" do
    # it "does not allocate inventory if inventory tracking is off" do
    #   request.accept = "application/json"
    #   inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
    #   store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
    #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>false)
    #   order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
    #   base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
    #   base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)
		#
    #   child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
    #   child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
    #   child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
    #   child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)
		#
    #   order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'unallocated')
    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'unallocated')
		#
    #   put :update_product_list, { :id => base_product.id, var: "qty", value: "100"  }
    #   expect(response.status).to eq(200)
    #
    #   base_product.reload
    #   child_product1.reload
    #   child_product2.reload
    #   order_item1.reload
    #   order_item2.reload
    #   expect(child_product1.base_product.product_inventory_warehousess.first.available_inv).to eq(100)
    #   expect(order_item1.inv_status).to eq("unallocated")
    #   expect(order_item2.inv_status).to eq("unallocated")
    # end
    it "allocates inventory to the child products if inventory tracking is on" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
      order = FactoryGirl.create(:order, :status=>'onhold', :store=>store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'unallocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'unallocated')

      put :update_product_list, { :id => base_product.id, var: "qty_on_hand", value: "100"  }
      expect(response.status).to eq(200)
      
      base_product.reload
      child_product1.reload
      child_product2.reload
      order_item1.reload
      order_item2.reload
      expect(child_product1.base_product.product_inventory_warehousess.first.available_inv).to eq(98)
      expect(order_item1.inv_status).to eq("allocated")
      expect(order_item2.inv_status).to eq("allocated")
    end
  end
end
