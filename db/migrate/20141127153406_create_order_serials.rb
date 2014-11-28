class CreateOrderSerials < ActiveRecord::Migration
  def change
    create_table :order_serials do |t|
      t.references :order
      t.references :product
      t.string :serial

      t.timestamps
    end
    add_index :order_serials, :order_id
    add_index :order_serials, :product_id
  end
end
