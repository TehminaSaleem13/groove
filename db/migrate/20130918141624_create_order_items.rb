class CreateOrderItems < ActiveRecord::Migration
  def change
    create_table :order_items do |t|
      t.string :sku
      t.integer :qty
      t.decimal :price
      t.decimal :row_total
      t.references :order

      t.timestamps
    end
    add_index :order_items, :order_id
  end
end
