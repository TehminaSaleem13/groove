require 'spec_helper'

describe Order do
   	it "should not split kits" do
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

	  order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
	            :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)

      result = order.should_the_kit_be_split('KITITEM2')
      expect(result).to eq(false)
    end

   it "should split kits" do
      order = FactoryGirl.create(:order, :status=>'awaiting')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2)

	  order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
	            :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)

      result = order.should_the_kit_be_split('KITITEM2')
      order_item2.scanned_status = 'scanned'
      order_item2.save
      order.reload
      order_item2.reload
      result = order.should_the_kit_be_split('KITITEM2')
      expect(result).to eq(true)
      order_item_kit.reload
      expect(order_item_kit.kit_split).to eq(true)
    end


   it "should reset scanned status of kits" do
      order = FactoryGirl.create(:order, :status=>'scanned')
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name, 
                    :scanned_status=>'scanned', :scanned_qty => 1)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit', 
                        :kit_parsing=>'depends')
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus=> product_kit_sku, :scanned_status=>'scanned', :scanned_qty=>1)

      kit_product2 = FactoryGirl.create(:product)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,   
            :product_kit_skus => product_kit_sku2, :scanned_status=>'scanned', :scanned_qty=>1)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
               :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name,
               :scanned_status=>'scanned', :scanned_qty => 1)

      order.reset_scanned_status

      order.reload
      expect(order.status).to eq('awaiting')

      order_item.reload
      expect(order_item.scanned_status).to eq('unscanned')
      expect(order_item.scanned_qty).to eq(0)

      order_item2.reload
      expect(order_item2.scanned_status).to eq('unscanned')
      expect(order_item2.scanned_qty).to eq(0)
      
      order_item_kit_product.reload
      expect(order_item_kit_product.scanned_status).to eq('unscanned')
      expect(order_item_kit_product.scanned_qty).to eq(0)     

      order_item_kit_product2.reload
      expect(order_item_kit_product2.scanned_status).to eq('unscanned')
      expect(order_item_kit_product2.scanned_qty).to eq(0)     
   end

   it "should add tag to the orders" do
      order = FactoryGirl.create(:order)
      tag = FactoryGirl.create(:order_tag)

      order.addtag(tag.id)

      expect(order.order_tags.length).to eq(1)
   end

   it "should remove tag from the orders" do
      order = FactoryGirl.create(:order)
      tag = FactoryGirl.create(:order_tag)

      order.addtag(tag.id)
      expect(order.order_tags.length).to eq(1)

      order.removetag(tag.id)
      expect(order.order_tags.length).to eq(0)
   end

    it "should create order and update available inventory count" do      
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      order = FactoryGirl.create(:order, :status=>'awaiting', :store => store)
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_inv_wh.reload

      expect(product_inv_wh.available_inv).to equal(23)
      expect(product_inv_wh.allocated_inv).to equal(2)
    end

    it "should create order then delete order and update allocated inventory count" do      
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      order = FactoryGirl.create(:order, :status=>'awaiting', :store => store)
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      order_item.destroy

      product_inv_wh.reload

      expect(product_inv_wh.available_inv).to equal(25)
      expect(product_inv_wh.allocated_inv).to equal(0)
    end

    it "should create order with status awaiting change it to onhold and update allocated inventory count" do      
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      order = FactoryGirl.create(:order, :status=>'awaiting', :store => store)
      
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(23)
      expect(product_inv_wh.allocated_inv).to eq(2)

      order.status = 'onhold'
      order.save

      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(25)
      expect(product_inv_wh.allocated_inv).to eq(0)
    end

    it "should create order which has a kit with single with status awaiting change it to onhold and update allocated inventory count" do      
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      order = FactoryGirl.create(:order, :status=>'awaiting', :store => store)
      
      product = FactoryGirl.create(:product, :is_kit => 1, :kit_parsing => 'single')
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')
      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product, :option_product_id=>kit_product.id, :qty=> 3)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(23)
      expect(product_inv_wh.allocated_inv).to eq(2)

      order.status = 'onhold'
      order.save

      product_inv_wh.reload
      expect(product_inv_wh.available_inv).to eq(25)
      expect(product_inv_wh.allocated_inv).to eq(0)
    end

    it "should create order which has a kit with individual status awaiting change it to onhold and update allocated inventory count" do      
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

      order = FactoryGirl.create(:order, :status=>'awaiting', :store => store)
      
      product = FactoryGirl.create(:product, :is_kit => 1, :kit_parsing => 'individual')
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      kit_product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')
      kit_product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> kit_product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product, :option_product_id=>kit_product.id, :qty=> 3)

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(19)
      expect(kit_product_inv_wh.allocated_inv).to eq(6)

      order.status = 'onhold'
      order.save

      kit_product_inv_wh.reload
      expect(kit_product_inv_wh.available_inv).to eq(25)
      expect(kit_product_inv_wh.allocated_inv).to eq(0)
    end
end
