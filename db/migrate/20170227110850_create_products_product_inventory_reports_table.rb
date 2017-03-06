class CreateProductsProductInventoryReportsTable < ActiveRecord::Migration
  def self.up
    create_table :products_product_inventory_reports, :id => false do |t|
        t.references :product_inventory_report
        t.references :product
    end
  end

  def self.down
    drop_table :products_product_inventory_reports
  end	
end
