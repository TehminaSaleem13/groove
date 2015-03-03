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

end
