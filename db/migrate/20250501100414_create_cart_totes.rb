class CreateCartTotes < ActiveRecord::Migration[6.1]
  def change
    create_table :cart_totes do |t|
      t.string :tote_id
      t.float :width
      t.float :height
      t.float :weight
      t.boolean :use_default_dimensions, default: true
      t.bigint :cart_row_id, null: false
      t.datetime :created_at, precision: 6, null: false
      t.datetime :updated_at, precision: 6, null: false
      t.index ["cart_row_id"], name: "index_cart_totes_on_cart_row_id"
    end
  end
end
