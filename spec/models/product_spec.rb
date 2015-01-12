require 'rails_helper'

describe Product do
   	it "should count total available local" do
      inv_wh = FactoryGirl.create(:inventory_warehouse)
      inv_wh_1 = FactoryGirl.create(:inventory_warehouse, :name=>'Inventory Warehouse test')

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)

      product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>inv_wh_1.id, :available_inv => 23)

      product.reload
      count = product.get_total_avail_loc

      expect(count).to eq(48)
   	end
end
