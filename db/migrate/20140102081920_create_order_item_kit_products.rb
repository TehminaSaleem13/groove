class CreateOrderItemKitProducts < ActiveRecord::Migration
  def change
    create_table :order_item_kit_products do |t|
      t.references :order_item
      t.references :product_kit_skus
      t.string :scanned_status, :default=>'unscanned'
      t.integer :scanned_qty, :default => 0

      t.timestamps
    end
    add_index :order_item_kit_products, :order_item_id
    add_index :order_item_kit_products, :product_kit_skus_id
  end
end
