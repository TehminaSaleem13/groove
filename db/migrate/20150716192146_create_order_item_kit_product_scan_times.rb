class CreateOrderItemKitProductScanTimes < ActiveRecord::Migration
  def change
    create_table :order_item_kit_product_scan_times do |t|
      t.datetime :scan_start
      t.datetime :scan_end
      t.integer :order_item_kit_product_id

      t.timestamps
    end
  end
end
