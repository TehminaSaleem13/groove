# require 'spec_helper'
require 'rails_helper'

RSpec.describe OrdersController, :type => :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
    @user_role = FactoryGirl.create(:role,:name=>'order_controller_tester_scan_pack')
    @user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    sign_in @user
  end
  
  describe "Order Status" do
    it "inventory is updated when order is deleted " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku, :status=>'new')
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :delete_orders, {:order_ids=>[order.id]}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      expect(product_inv_wh.allocated_inv).to eq(3)
      expect(product_inv_wh.available_inv).to eq(27)
    end

    it "inventory is updated when order is moved from awaiting to cancelled " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'cancelled'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(3)
      expect(product_inv_wh.available_inv).to eq(27)
      expect(order_item1.inv_status).to eq('unallocated')
      expect(order_item2.inv_status).to eq('unallocated')
    end

    it "inventory is updated when order is moved from serviceissue to cancelled " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'cancelled'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(3)
      expect(product_inv_wh.available_inv).to eq(27)
      expect(order_item1.inv_status).to eq('unallocated')
      expect(order_item2.inv_status).to eq('unallocated')
    end

    it "inventory is updated when order is moved from cancelled to awaiting " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'cancelled', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'unallocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'unallocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'awaiting'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(7)
      expect(product_inv_wh.available_inv).to eq(23)
      expect(order_item1.inv_status).to eq('allocated')
      expect(order_item2.inv_status).to eq('allocated')
    end

    it "inventory is updated when order is moved from cancelled to serviceissue " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'cancelled', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'unallocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'unallocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'serviceissue'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(7)
      expect(product_inv_wh.available_inv).to eq(23)
      expect(order_item1.inv_status).to eq('allocated')
      expect(order_item2.inv_status).to eq('allocated')
    end

    it "inventory remains unchanged when order is updated from awaiting to serviceissue " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'serviceissue'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(5)
      expect(product_inv_wh.available_inv).to eq(25)
      expect(order_item1.inv_status).to eq('allocated')
      expect(order_item2.inv_status).to eq('allocated')
    end

    it "inventory remains unchanged when order is updated from serviceissue to awaiting " do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      @user_role.add_edit_order_items = true
      @user_role.save
      order = FactoryGirl.create(:order, :status=>'serviceissue', :increment_id=>'1234567890', :store => store)
      base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
      base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)

      child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
      child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
      child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
      child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)

      order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')

      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, :product=> base_product,
        :inventory_warehouse_id =>inv_wh.id, 
        :available_inv => 25, :allocated_inv => 5)
      
      put :change_orders_status, {:order_ids=>[order.id], :status=>'awaiting'}
      expect(response.status).to eq(200)
      product_inv_wh.reload
      order_item1.reload
      order_item2.reload
      expect(product_inv_wh.allocated_inv).to eq(5)
      expect(product_inv_wh.available_inv).to eq(25)
      expect(order_item1.inv_status).to eq('allocated')
      expect(order_item2.inv_status).to eq('allocated')
    end

		#turning inventory on and off will be handled by a batch process
    # it "inventory does not update if inventory_tracking is off when order is moved from awaiting to cancelled " do
    #   request.accept = "application/json"
    #   inv_wh = FactoryGirl.create(:inventory_warehouse)
    #   general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>false)
    #   store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
    #   @user_role.add_edit_order_items = true
    #   @user_role.save
    #   order = FactoryGirl.create(:order, :status=>'awaiting', :increment_id=>'1234567890', :store => store)
    #   base_product = FactoryGirl.create(:product, :name=>"base product", :status=>'active')
    #   base_product_sku = FactoryGirl.create(:product_sku, :product=> base_product)
		#
    #   child_product1 = FactoryGirl.create(:product, :name=>"child product1", :base_sku=>base_product.primary_sku)
    #   child_product_sku1 = FactoryGirl.create(:product_sku, :sku=>'SKU1', :product=> child_product1)
    #   child_product2 = FactoryGirl.create(:product, :name=>"child product2", :base_sku=>base_product.primary_sku)
    #   child_product_sku2 = FactoryGirl.create(:product_sku, :sku=>'SKU2', :product=> child_product2)
		#
    #   order_item1 = FactoryGirl.create(:order_item, :product_id=>child_product1.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product1.name, :inv_status=>'allocated')
    #   order_item2 = FactoryGirl.create(:order_item, :product_id=>child_product2.id,
    #                 :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>child_product2.name, :inv_status=>'allocated')
		#
    #   product_inv_wh = FactoryGirl.create(
    #     :product_inventory_warehouse, :product=> base_product,
    #     :inventory_warehouse_id =>inv_wh.id,
    #     :available_inv => 25, :allocated_inv => 5)
    #
    #   put :change_orders_status, {:order_ids=>[order.id], :status=>'cancelled'}
    #   expect(response.status).to eq(200)
    #   product_inv_wh.reload
    #   order_item1.reload
    #   order_item2.reload
    #   expect(product_inv_wh.allocated_inv).to eq(5)
    #   expect(product_inv_wh.available_inv).to eq(25)
    #   expect(order_item1.inv_status).to eq('allocated')
    #   expect(order_item2.inv_status).to eq('allocated')
    # end
  end
end
