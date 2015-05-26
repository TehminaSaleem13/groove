class OrderItemsProductLotsJoinTable < ActiveRecord::Migration
  def up
  	create_table :order_items_product_lots, :id => false do |t|
      t.integer :order_item_id
      t.integer :product_lot_id
    end
  end

  def down
  	drop_table :order_items_product_lots
  end
end
