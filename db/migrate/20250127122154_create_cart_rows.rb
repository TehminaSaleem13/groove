class CreateCartRows < ActiveRecord::Migration[6.1]
  def change
    create_table :cart_rows do |t|
      t.string :row_name
      t.integer :row_count
      t.references :cart, null: false, foreign_key: true

      t.timestamps
    end
  end
end
