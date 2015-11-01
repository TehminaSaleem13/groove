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

      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)
      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")

      order = FactoryGirl.create(:order, :status=>'awaiting')
      order_item = FactoryGirl.create(:order_item, :product_id=>product_alias.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product_alias.name)

      put :set_alias, { :id => product_orig.id, product_alias_ids: [product_alias.id] }

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

      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)
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

      put :set_alias, { :id => product_orig.id, product_alias_ids: [product1.id, product2.id] }

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

      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)
      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")

      kit_product = FactoryGirl.create(:product, is_kit: 1)
      product_kit_sku = FactoryGirl.create(:product_kit_sku, product_id: kit_product.id, option_product_id: product_alias.id)

      put :set_alias, { :id => product_orig.id, product_alias_ids: [product_alias.id] }

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

      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)
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

      put :set_alias, { :id => product_orig.id, product_alias_ids: [product1.id, product2.id] }

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

  describe "adjusts inventory" do
    it "while setting a product as an alias of another product" do
      request.accept = "application/json"

      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)
      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)
      
      product_orig_inv_wh = product_orig.primary_warehouse
      product_orig_inv_wh.update_attributes(:available_inv => 25, :allocated_inv => 5, :inventory_warehouse_id =>inv_wh.id)
      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")
      
      product_alias_inv_wh = product_alias.primary_warehouse
      product_alias_inv_wh.update_attributes(:allocated_inv => 5, :inventory_warehouse_id =>inv_wh.id)

      put :set_alias, { :id => product_orig.id, product_alias_ids: [product_alias.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(2)
      expect(product_orig.product_barcodes.length).to eq(2)
      expect(Product.all.length).to eq(1)
      
      expect(product_orig.primary_warehouse.available_inv).to eq(20)
      expect(product_orig.primary_warehouse.allocated_inv).to eq(10)
    end

    it "while setting a product as an alias of a kit" do
      request.accept = "application/json"

      general_setting = FactoryGirl.create(:general_setting, :inventory_tracking=>true, :hold_orders_due_to_inventory=>true)
      inv_wh = FactoryGirl.create(:inventory_warehouse, :is_default => true)

      product1 = FactoryGirl.create(:product, :name=>"product1")
      product1_sku = FactoryGirl.create(:product_sku, :product=> product1, :sku=>'product_sku1')
      product1_barcode = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>"BARCODE1")

      product2 = FactoryGirl.create(:product, :name=>"product2")
      product2_sku = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'product_sku2')
      product2_barcode = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"BARCODE2")

      kit_product_orig = FactoryGirl.create(:product, is_kit: 1)
      kit_product_orig_sku1 = FactoryGirl.create(:product_kit_sku, product_id: kit_product_orig.id, option_product_id: product1.id)
      kit_product_orig_sku2 = FactoryGirl.create(:product_kit_sku, product_id: kit_product_orig.id, option_product_id: product2.id, qty: 2)

      kit_product_orig_sku = FactoryGirl.create(:product_sku, :product=> kit_product_orig)
      kit_product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product_orig)
      kit_product_orig_inv_wh = kit_product_orig.primary_warehouse
      kit_product_orig_inv_wh.update_attributes(:available_inv => 25, :allocated_inv => 5, :inventory_warehouse_id =>inv_wh.id)
      product1_inv_wh = product1.primary_warehouse
      product1_inv_wh.update_attributes(:available_inv => 25, :allocated_inv => 5, :inventory_warehouse_id =>inv_wh.id)
      product2_inv_wh = product2.primary_warehouse
      product2_inv_wh.update_attributes(:available_inv => 50, :allocated_inv => 10, :inventory_warehouse_id =>inv_wh.id)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")
      
      product_alias_inv_wh = product_alias.primary_warehouse
      product_alias_inv_wh.update_attributes(:allocated_inv => 5, :inventory_warehouse_id =>inv_wh.id)

      put :set_alias, { :id => kit_product_orig.id, product_alias_ids: [product_alias.id] }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      kit_product_orig.reload
      expect(kit_product_orig.product_skus.length).to eq(2)
      expect(kit_product_orig.product_barcodes.length).to eq(2)
      expect(Product.all.length).to eq(3)
      
      expect(product1.primary_warehouse.available_inv).to eq(20)
      expect(product2.primary_warehouse.available_inv).to eq(40)
      expect(product1.primary_warehouse.allocated_inv).to eq(10)
      expect(product2.primary_warehouse.allocated_inv).to eq(20)
    end
  end
end
