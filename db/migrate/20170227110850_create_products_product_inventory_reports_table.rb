class CreateProductsProductInventoryReportsTable < ActiveRecord::Migration[5.1]
  def self.up
    create_table :products_product_inventory_reports, :id => false do |t|
        t.references :product_inventory_report, index: false
        t.references :product, index: false
    end
  end

  def self.down
    drop_table :products_product_inventory_reports
  end	
end