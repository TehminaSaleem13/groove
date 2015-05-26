class CreateProductLots < ActiveRecord::Migration
  def up
    create_table :product_lots do |t|
      t.references :product
      t.references :order_item
    	t.string :lot_number

      t.timestamps
    end
    add_index :product_lots, :product_id
    add_index :product_lots, :order_item_id
  end

  def down
  	drop_table :product_lots
  end
end
