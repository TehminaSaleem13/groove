class CreateOrderItemScanTimes < ActiveRecord::Migration
  def change
    create_table :order_item_scan_times do |t|
      t.datetime :scan_start
      t.datetime :scan_end
      t.integer :order_item_id
      t.timestamps
    end
  end
end
