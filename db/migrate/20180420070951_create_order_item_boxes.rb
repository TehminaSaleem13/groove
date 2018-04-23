class CreateOrderItemBoxes < ActiveRecord::Migration
  def change
    create_table :order_item_boxes do |t|
      t.integer :box_id
      t.integer :order_item_id
      t.integer :item_qty
      t.integer :kit_id
      t.timestamps
    end
  end
end
