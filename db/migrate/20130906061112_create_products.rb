class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :store_product_id, :null=>false
      t.string :name, :null=>false
      t.string :product_type
      t.references :store, :null=>false

      t.timestamps
    end
    add_index :products, :store_id
  end
end
